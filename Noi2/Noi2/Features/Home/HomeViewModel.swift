//
//  HomeViewModel.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import WidgetKit
import UIKit
import OSLog

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Couple state
    enum CoupleState: Equatable {
        case noCouple
        case createdWaiting(code: String, membersCount: Int)
        case joinedPending(code: String, membersCount: Int)
        case matched(code: String)
    }

    // MARK: - Services
    private let messageService = LoveMessageService()
    private let ck = CloudKitPushService.shared

    // MARK: - Logger
    private let log = Logger(subsystem: "ro.csx.Noi2x", category: "HomeVM")

    // MARK: - Published state
    @Published var profile: UserProfile?
    @Published var couple: Couple?
    @Published private(set) var state: CoupleState = .noCouple
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isUploadingWidgetPhoto = false

    // Last message (persisted per user+couple)
    @Published var lastSent: LastSent?

    // UI bindings
    @Published var generatedCode: String = ""
    @Published var joinCode: String = ""
    @Published var pickedAnniversary: Date = Date()
    @Published var isEditingAnniversary = false

    // Messaging / widget
    @Published var currentUserName: String = ""

    // MARK: - Derived
    var currentUid: String { Auth.auth().currentUser?.uid ?? "" }
    var coupleId: String { couple?.id ?? "" }

    // MARK: - Listeners
    private var coupleListener: ListenerRegistration?
    private var ckObserver: NSObjectProtocol?
    private var isMessageSyncActive = false

    deinit {
        coupleListener?.remove()
        messageService.stopListening()
        if let ckObserver { NotificationCenter.default.removeObserver(ckObserver) }
    }

    // MARK: - Lifecycle
    func load() async {
        guard let user = Auth.auth().currentUser else {
            #if DEBUG
            log.debug("[load] No Firebase user, skipping.")
            #endif
            return
        }

        #if DEBUG
        log.debug("[load] start uid=\(user.uid, privacy: .public)")
        #endif

        isLoading = true
        defer { isLoading = false }

        do {
            let p = try await FirestoreService.bootstrapCurrentUser()
            self.profile = p
            self.currentUserName = p.displayName

            #if DEBUG
            log.debug("[load] bootstrap OK coupleId=\(p.coupleId ?? "nil", privacy: .public)")
            #endif

            // Load locally persisted "last sent"
            self.loadLastSent()

            if let coupleId = p.coupleId {
                listenCouple(id: coupleId)
                await startCloudKitSync(coupleId: coupleId)
            } else {
                self.state = .noCouple
            }
        } catch {
            mapErrorToUserMessage(error)
            #if DEBUG
            log.error("[load] error: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }

    // MARK: - Couple listener
    private func listenCouple(id: String) {
        coupleListener?.remove()

        #if DEBUG
        log.debug("[listenCouple] attach id=\(id, privacy: .public)")
        #endif

        coupleListener = FirestoreService.couples.document(id).addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                guard let self else { return }

                if let err = err {
                    self.mapErrorToUserMessage(err)
                    #if DEBUG
                    self.log.error("[listener] error: \(err.localizedDescription, privacy: .public)")
                    #endif
                    return
                }
                guard let data = snap else {
                    #if DEBUG
                    self.log.debug("[listener] no snapshot data")
                    #endif
                    return
                }

                if let c: Couple = try? data.data(as: Couple.self) {
                    self.couple = c
                    self.recomputeState()

                    if let anniv = c.anniversary {
                        SharedWidgetStore.saveAnniversary(anniv)
                    }

                    if let urlStr = c.widgetPhotoURL, let url = URL(string: urlStr) {
                        Task.detached { [weak self] in
                            guard let self else { return }
                            do {
                                let data = try await StorageService.downloadData(from: url)
                                if let img = UIImage(data: data) {
                                    SharedWidgetStore.saveWidgetPhoto(img)
                                }
                            } catch {
                                #if DEBUG
                                self.log.debug("[widgetPhoto] download failed: \(error.localizedDescription, privacy: .public)")
                                #endif
                            }
                        }
                    }

                    // Keep "last sent" key in sync (couple changes)
                    self.loadLastSent()
                } else {
                    #if DEBUG
                    self.log.error("[listener] failed to decode Couple")
                    #endif
                }

                switch self.state {
                case .matched:
                    if !self.isMessageSyncActive {
                        self.startMessageSync()
                    }
                default:
                    if self.isMessageSyncActive {
                        self.stopMessageSync()
                    }
                }
            }
        }
    }

    // MARK: - Couple create / join / leave
    func generateAndCreateCouple() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let code = Self.secureCode(length: 6)
            let coupleId = try await FirestoreService.createCouple(ownerUid: uid, code: code)
            try await FirestoreService.setUserCouple(uid: uid, coupleId: coupleId)
            self.generatedCode = code
            listenCouple(id: coupleId)

            await startCloudKitSync(coupleId: coupleId)
            await ck.bump(coupleId: coupleId, eventType: "status")
        } catch {
            mapErrorToUserMessage(error)
        }
    }

    func joinCoupleByCode() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !code.isEmpty else {
                self.errorMessage = "Enter a valid code."
                return
            }

            guard let found = try await FirestoreService.findCoupleBy(code: code) else {
                self.errorMessage = "No couple found for this code."
                return
            }

            if found.memberUids.count >= 2 {
                self.errorMessage = "Couple is already full."
                return
            }

            guard let coupleId = found.id else { return }

            try await FirestoreService.joinCouple(coupleId: coupleId, uid: uid)
            try await FirestoreService.setUserCouple(uid: uid, coupleId: coupleId)

            listenCouple(id: coupleId)
            await startCloudKitSync(coupleId: coupleId)
            await ck.bump(coupleId: coupleId, eventType: "status")
        } catch {
            mapErrorToUserMessage(error)
        }
    }

    func leaveCouple() async {
        guard let uid = Auth.auth().currentUser?.uid, let cid = couple?.id else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await FirestoreService.removeMember(coupleId: cid, uid: uid)
            if let membersCount = couple?.memberUids.count, membersCount <= 1 {
                try await FirestoreService.deleteCoupleIfEmpty(coupleId: cid)
            }
            try await FirestoreService.setUserCouple(uid: uid, coupleId: nil)

            Task { await ck.bump(coupleId: cid, eventType: "status") }

            // Dispose listeners/state
            coupleListener?.remove(); coupleListener = nil
            stopMessageSync()
            couple = nil
            state = .noCouple
            generatedCode = ""
            joinCode = ""

            persistLastSent(nil)
            lastSent = nil

            if let ckObserver {
                NotificationCenter.default.removeObserver(ckObserver)
                self.ckObserver = nil
            }
        } catch {
            mapErrorToUserMessage(error)
        }
    }

    // MARK: - Widget photo
    func setWidgetPhoto(_ image: UIImage) async {
        guard !coupleId.isEmpty, !isUploadingWidgetPhoto else { return }

        isUploadingWidgetPhoto = true
        isLoading = true
        defer {
            isUploadingWidgetPhoto = false
            isLoading = false
        }

        do {
            let url = try await StorageService.uploadWidgetPhoto(coupleId: coupleId, image: image)
            try await FirestoreService.couples.document(coupleId).updateData([
                "widgetPhotoURL": url.absoluteString
            ])
            SharedWidgetStore.saveWidgetPhoto(image)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            mapErrorToUserMessage(error)
        }
    }

    // MARK: - Anniversary
    func saveAnniversary() async {
        guard let cid = couple?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await FirestoreService.setAnniversary(coupleId: cid, date: pickedAnniversary)
            isEditingAnniversary = false
            SharedWidgetStore.saveAnniversary(pickedAnniversary)
            WidgetCenter.shared.reloadAllTimelines()
            await ck.bump(coupleId: cid, eventType: "anniversary")
        } catch {
            mapErrorToUserMessage(error)
        }
    }

    func startEditingAnniversary() {
        pickedAnniversary = couple?.anniversary ?? Date()
        isEditingAnniversary = true
    }

    func cancelEditingAnniversary() {
        isEditingAnniversary = false
    }

    // MARK: - State recompute
    private func recomputeState() {
        guard let couple else { state = .noCouple; return }
        let members = couple.memberUids.count
        let code = couple.code
        guard let myUid = Auth.auth().currentUser?.uid else { return }

        if members >= 2 {
            state = .matched(code: code)
        } else if couple.memberUids.contains(myUid) {
            if generatedCode.isEmpty { generatedCode = code }
            state = .createdWaiting(code: code, membersCount: members)
        } else {
            state = .joinedPending(code: code, membersCount: members)
        }
    }

    // MARK: - Code generation (secure, unambiguous alphabet)
    private static func secureCode(length: Int = 6) -> String {
        precondition(length > 0)
        // Excludes easily-confused chars (I, O, 1, 0)
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var result = [Character]()
        result.reserveCapacity(length)

        while result.count < length {
            var bytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            if status != errSecSuccess {
                result.append(contentsOf: UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(length - result.count))
                break
            }
            for b in bytes where result.count < length {
                if b < alphabet.count {
                    result.append(alphabet[Int(b)])
                }
            }
        }
        return String(result)
    }

    // MARK: - Widgets (manual update helper)
    func updateWidgetWithLatestPartnerMessage(text: String, fromUid: String, fromName: String) {
        let note = LoveNote(text: text, fromUid: fromUid, fromName: fromName, updatedAt: .now)
        LoveStore.save(note)
        WidgetCenter.shared.reloadTimelines(ofKind: "Noi2LoveWidget")
    }

    // MARK: - Messaging API
    func startMessageSync() {
        messageService.startListening(coupleId: coupleId, currentUid: currentUid)
        isMessageSyncActive = true
    }

    func stopMessageSync() {
        messageService.stopListening()
        isMessageSyncActive = false
    }

    func sendLoveMessage(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !coupleId.isEmpty, !currentUid.isEmpty else { return }

        let finalText = String(t.prefix(80))

        messageService.send(
            to: coupleId,
            text: finalText,
            fromUid: currentUid,
            fromName: profile?.displayName ?? currentUserName
        )

        let last = LastSent(text: finalText, date: .now)
        self.lastSent = last
        persistLastSent(last)

        Task { await ck.bump(coupleId: coupleId, eventType: "message") }
    }

    // MARK: - CloudKit sync bootstrap + refetch on push
    func startCloudKitSync(coupleId: String) async {
        _ = try? await ck.ensureSignalRecord(for: coupleId)
        await ck.recreateSubscription(for: coupleId)

        if ckObserver == nil {
            ckObserver = NotificationCenter.default.addObserver(
                forName: .init("CKSilentSignal"), object: nil, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { await self.refetchCoupleSnapshot() }
            }
        }
    }

    /// Forces a quick snapshot refresh from Firestore (useful if any push was missed).
    private func refetchCoupleSnapshot() async {
        guard let cid = (couple?.id ?? profile?.coupleId) else { return }
        do {
            let snap = try await FirestoreService.couples.document(cid).getDocument()
            if let c: Couple = try? snap.data(as: Couple.self) {
                self.couple = c
                self.recomputeState()
                if case .matched = self.state { self.startMessageSync() }
                self.loadLastSent()
            }
        } catch {
            #if DEBUG
            log.debug("[refetch] error: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }

    // MARK: - Last Sent persistence
    private var lastSentKey: String {
        let uid = currentUid.isEmpty ? "nouid" : currentUid
        let cid = coupleId.isEmpty ? (profile?.coupleId ?? "nocouple") : coupleId
        return "lastSent_\(uid)_\(cid)"
    }

    private func loadLastSent() {
        guard let data = UserDefaults.standard.data(forKey: lastSentKey) else { return }
        if let value = try? JSONDecoder().decode(LastSent.self, from: data) {
            self.lastSent = value
        }
    }

    private func persistLastSent(_ value: LastSent?) {
        if let v = value, let data = try? JSONEncoder().encode(v) {
            UserDefaults.standard.set(data, forKey: lastSentKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastSentKey)
        }
    }

    // MARK: - Error mapping
    private func mapErrorToUserMessage(_ error: Error) {
        // Keep user-facing messages friendly; log details in DEBUG only
        self.errorMessage = "Something went wrong. Please try again."
        #if DEBUG
        log.debug("[err] \(error.localizedDescription, privacy: .public)")
        #endif
    }
}
