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
    private let ck = CloudKitPushService.shared // CloudKit mirror service (push trigger)

    // MARK: - Published state
    @Published var profile: UserProfile?
    @Published var couple: Couple?
    @Published var state: CoupleState = .noCouple
    @Published var isLoading = false
    @Published var errorMessage: String?

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

    deinit {
        coupleListener?.remove()
        messageService.stopListening()
        if let ckObserver { NotificationCenter.default.removeObserver(ckObserver) }
    }

    // MARK: - Lifecycle
    func load() async {
        guard let user = Auth.auth().currentUser else {
            print("[DBG] No Firebase user, skipping load()")
            return
        }

        print("[DBG] load() started for uid:", user.uid)
        isLoading = true
        defer { isLoading = false }

        do {
            let p = try await FirestoreService.bootstrapCurrentUser()
            self.profile = p
            print("[DBG] bootstrapCurrentUser OK, coupleId:", p.coupleId ?? "nil")

            // load locally persisted "last sent" (uses uid + coupleId key)
            self.loadLastSent()

            if let coupleId = p.coupleId {
                print("[DBG] -> start listenCouple(id: \(coupleId))")
                listenCouple(id: coupleId)
                await startCloudKitSync(coupleId: coupleId)
            } else {
                print("[DBG] -> noCouple state")
                self.state = .noCouple
            }
        } catch {
            self.errorMessage = error.localizedDescription
            print("[ERR] load() failed:", error.localizedDescription)
        }
    }

    // MARK: - Couple listener
    private func listenCouple(id: String) {
        coupleListener?.remove()
        print("[DBG] listenCouple() attaching listener for", id)

        coupleListener = FirestoreService.couples.document(id).addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                if let err = err {
                    print("[ERR] Firestore listener error:", err.localizedDescription)
                    self?.errorMessage = err.localizedDescription
                    return
                }
                guard let data = snap else {
                    print("[DBG] Listener triggered but no data")
                    return
                }

                print("[DBG] Listener snapshot received for couple \(id)")
                if let c: Couple = try? data.data(as: Couple.self) {
                    print("[DBG] Couple decoded OK, members:", c.memberUids, "code:", c.code)
                    self?.couple = c
                    self?.recomputeState()

                    // re-evaluate persisted lastSent key now that coupleId may have changed
                    self?.loadLastSent()
                } else {
                    print("[ERR] Failed to decode Couple model")
                }

                if case .matched = self?.state {
                    print("[DBG] -> state = matched → startMessageSync()")
                    self?.startMessageSync()
                } else {
                    print("[DBG] -> state != matched → stopMessageSync()")
                    self?.stopMessageSync()
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
            let code = Self.generateCode()
            let coupleId = try await FirestoreService.createCouple(ownerUid: uid, code: code)
            try await FirestoreService.setUserCouple(uid: uid, coupleId: coupleId)
            self.generatedCode = code
            listenCouple(id: coupleId)

            // CloudKit: ensure record + subscription, then signal a "status" bump
            await startCloudKitSync(coupleId: coupleId)
            await ck.bump(coupleId: coupleId, eventType: "status")
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func joinCoupleByCode() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[ERR] joinCoupleByCode → no user")
            return
        }
        print("[DBG] joinCoupleByCode() start for uid:", uid, "code:", joinCode)

        isLoading = true
        defer { isLoading = false }

        do {
            let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !code.isEmpty else {
                self.errorMessage = "Enter a valid code."
                print("[ERR] joinCoupleByCode → empty code")
                return
            }

            print("[DBG] findCoupleBy(code: \(code)) …")
            guard let found = try await FirestoreService.findCoupleBy(code: code) else {
                print("[ERR] No couple found for code:", code)
                self.errorMessage = "No couple found for this code."
                return
            }

            print("[DBG] Found coupleId:", found.id ?? "nil", "members:", found.memberUids)

            if found.memberUids.count >= 2 {
                print("[ERR] Couple already full.")
                self.errorMessage = "Couple is already full."
                return
            }

            guard let coupleId = found.id else {
                print("[ERR] Couple has nil id!")
                return
            }

            print("[DBG] -> joinCouple(\(coupleId), \(uid)) …")
            try await FirestoreService.joinCouple(coupleId: coupleId, uid: uid)
            print("[DBG] joinCouple OK → setting userCouple")
            try await FirestoreService.setUserCouple(uid: uid, coupleId: coupleId)
            print("[DBG] setUserCouple OK → listenCouple")

            listenCouple(id: coupleId)
            await startCloudKitSync(coupleId: coupleId)
            await ck.bump(coupleId: coupleId, eventType: "status")

            print("joinCoupleByCode() finished successfully")
        } catch {
            self.errorMessage = error.localizedDescription
            print("[ERR] joinCoupleByCode() exception:", error.localizedDescription)
        }
    }

    func leaveCouple() async {
        guard let uid = Auth.auth().currentUser?.uid,
              let cid = couple?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await FirestoreService.removeMember(coupleId: cid, uid: uid)
            if let membersCount = couple?.memberUids.count, membersCount <= 1 {
                try await FirestoreService.deleteCoupleIfEmpty(coupleId: cid)
            }
            try await FirestoreService.setUserCouple(uid: uid, coupleId: nil)

            Task { await ck.bump(coupleId: cid, eventType: "status") }

            coupleListener?.remove(); coupleListener = nil
            messageService.stopListening()
            couple = nil
            state = .noCouple
            generatedCode = ""
            joinCode = ""

            persistLastSent(nil)
            lastSent = nil

            if let ckObserver { NotificationCenter.default.removeObserver(ckObserver); self.ckObserver = nil }
        } catch {
            self.errorMessage = error.localizedDescription
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

            // CloudKit: bump "anniversary"
            await ck.bump(coupleId: cid, eventType: "anniversary")
        } catch {
            self.errorMessage = error.localizedDescription
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
        guard let couple = couple else { state = .noCouple; return }
        let members = couple.memberUids.count
        let code = couple.code
        guard let myUid = Auth.auth().currentUser?.uid else { return }

        if members >= 2 {
            state = .matched(code: code)
        } else {
            if couple.memberUids.contains(myUid) {
                if generatedCode.isEmpty { generatedCode = code }
                state = .createdWaiting(code: code, membersCount: members)
            } else {
                state = .joinedPending(code: code, membersCount: members)
            }
        }
    }

    private static func generateCode(length: Int = 6) -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    // MARK: - Widget manual update (handy for testing)
    func updateWidgetWithLatestPartnerMessage(text: String, fromUid: String, fromName: String) {
        let note = LoveNote(text: text, fromUid: fromUid, fromName: fromName, updatedAt: .now)
        LoveStore.save(note)
        WidgetCenter.shared.reloadTimelines(ofKind: "Noi2LoveWidget")
    }

    // MARK: - Messaging API (via LoveMessageService)
    func startMessageSync() {
        messageService.startListening(coupleId: coupleId, currentUid: currentUid)
    }

    func stopMessageSync() {
        messageService.stopListening()
    }

    func sendLoveMessage(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !coupleId.isEmpty, !currentUid.isEmpty else { return }

        let finalText = String(t.prefix(80))

        // actual send
        messageService.send(
            to: coupleId,
            text: finalText,
            fromUid: currentUid,
            fromName: currentUserName
        )

        // update UI + persist locally
        let last = LastSent(text: finalText, date: .now)
        self.lastSent = last
        persistLastSent(last)

        // CloudKit: bump "message" (fire-and-forget)
        Task { await ck.bump(coupleId: coupleId, eventType: "message") }
    }

    // MARK: - CloudKit sync bootstrap + refetch on push
    func startCloudKitSync(coupleId: String) async {
        // 1) Ensure the signal record exists (also bootstraps schema in Development)
        _ = try? await ck.ensureSignalRecord(for: coupleId)

        // 2) Force (re)create the subscription on THIS device with alert payload
        await ck.recreateSubscription(for: coupleId)

        // 3) Listen for CloudKit push (alert or silent) and refresh Firestore as a safety net
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
        guard let cid = couple?.id ?? profile?.coupleId else { return }
        do {
            let snap = try await FirestoreService.couples.document(cid).getDocument()
            if let c: Couple = try? snap.data(as: Couple.self) {
                self.couple = c
                self.recomputeState()
                if case .matched = self.state { self.startMessageSync() }

                // ensure lastSent key is in sync (in case coupleId changed)
                self.loadLastSent()
            }
        } catch {
            #if DEBUG
            print("[CK Sync] refetchCoupleSnapshot error:", error.localizedDescription)
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
}
