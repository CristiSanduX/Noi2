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

    // MARK: - Published state
    @Published var profile: UserProfile?
    @Published var couple: Couple?
    @Published var state: CoupleState = .noCouple
    @Published var isLoading = false
    @Published var errorMessage: String?

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

    deinit {
        coupleListener?.remove()
        messageService.stopListening()
    }

    // MARK: - Lifecycle
    func load() async {
        guard Auth.auth().currentUser != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let p = try await FirestoreService.bootstrapCurrentUser()
            self.profile = p
            if let coupleId = p.coupleId {
                listenCouple(id: coupleId)
            } else {
                self.state = .noCouple
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Couple create/join/leave
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
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func joinCoupleByCode() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !code.isEmpty else { self.errorMessage = "Enter a valid code."; return }
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
        } catch {
            self.errorMessage = error.localizedDescription
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

            // Reset local state
            coupleListener?.remove(); coupleListener = nil
            messageService.stopListening()
            couple = nil
            state = .noCouple
            generatedCode = ""
            joinCode = ""
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
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func startEditingAnniversary() {
        if let current = couple?.anniversary {
            pickedAnniversary = current
        } else {
            pickedAnniversary = Date()
        }
        isEditingAnniversary = true
    }

    func cancelEditingAnniversary() {
        isEditingAnniversary = false
    }

    // MARK: - Couple listener
    private func listenCouple(id: String) {
        coupleListener?.remove()
        coupleListener = FirestoreService.couples.document(id).addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                if let err = err { self?.errorMessage = err.localizedDescription; return }
                guard let data = snap else { return }
                self?.couple = try? data.data(as: Couple.self)
                self?.recomputeState()

                if case .matched = self?.state {
                    self?.startMessageSync()
                } else {
                    self?.stopMessageSync()
                }
            }
        }
    }

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

    // MARK: - Widget manual update (util la testare)
    func updateWidgetWithLatestPartnerMessage(text: String, fromUid: String, fromName: String) {
        let note = LoveNote(text: text, fromUid: fromUid, fromName: fromName, updatedAt: .now)
        LoveStore.save(note)
        WidgetCenter.shared.reloadTimelines(ofKind: "Noi2LoveWidget")
    }

    // MARK: - Messaging API (folosesc LoveMessageService)
    func startMessageSync() {
        messageService.startListening(coupleId: coupleId, currentUid: currentUid)
    }

    func stopMessageSync() {
        messageService.stopListening()
    }

    func sendLoveMessage(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !coupleId.isEmpty, !currentUid.isEmpty else { return }
        messageService.send(
            to: coupleId,
            text: String(t.prefix(80)),
            fromUid: currentUid,
            fromName: currentUserName
        )
    }
}
