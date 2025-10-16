//
//  HomeViewModel.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class HomeViewModel: ObservableObject {
    enum CoupleState: Equatable {
        case noCouple
        case createdWaiting(code: String, membersCount: Int)
        case joinedPending(code: String, membersCount: Int)
        case matched(code: String)
    }

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

    private var coupleListener: ListenerRegistration?

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

            coupleListener?.remove(); coupleListener = nil
            couple = nil
            state = .noCouple
            generatedCode = ""
            joinCode = ""
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func listenCouple(id: String) {
        coupleListener?.remove()
        coupleListener = FirestoreService.couples.document(id).addSnapshotListener { [weak self] snap, err in
            Task { @MainActor in
                if let err = err { self?.errorMessage = err.localizedDescription; return }
                guard let data = snap else { return }
                self?.couple = try? data.data(as: Couple.self)
                self?.recomputeState()
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
}
