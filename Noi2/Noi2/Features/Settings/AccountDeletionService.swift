//
//  AccountDeletionService.swift
//  Noi2
//
//  Created by Cristi Sandu on 01.11.2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import CloudKit

final class AccountDeletionService {
    static let shared = AccountDeletionService()
    private init() {}

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    enum DeletionError: Error { case noUser }

    @MainActor
    func deleteCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else { throw DeletionError.noUser }
        let uid = user.uid

        // 1) Read data you need to unwind links (e.g., coupleId)
        let userRef = db.collection("users").document(uid)
        let userSnap = try await userRef.getDocument()
        let coupleId = userSnap.data()?["coupleId"] as? String

        // 2) Firestore writes (unlink and delete personal docs)
        try await db.runTransaction { txn, _ in
            if let coupleId {
                let coupleRef = self.db.collection("couples").document(coupleId)
                if let coupleSnap = try? txn.getDocument(coupleRef),
                   var data = coupleSnap.data() {

                    // Remove this uid from any member fields you use
                    // Example for array-based membership:
                    if var members = data["members"] as? [String] {
                        members.removeAll { $0 == uid }
                        data["members"] = members
                    }
                    // Example for role fields:
                    if data["userA"] as? String == uid { data["userA"] = FieldValue.delete() }
                    if data["userB"] as? String == uid { data["userB"] = FieldValue.delete() }

                    // Optional: reset state if a single user remains
                    data["status"] = "waiting"
                    txn.setData(data, forDocument: coupleRef, merge: true)

                    // If no one remains, delete the couple record
                    if (data["members"] as? [String])?.isEmpty == true ||
                       ((data["userA"] == nil) && (data["userB"] == nil)) {
                        txn.deleteDocument(coupleRef)
                    }
                }
            }

            // Delete the user doc last in the transaction
            txn.deleteDocument(userRef)
            return nil
        }

        // 3) Storage cleanup (ONLY user-owned paths)
        // Example: users/{uid}/*
        let userFolder = storage.reference().child("users/\(uid)")
        try? await deleteAllFilesUnder(userFolder)


        do {
            try await user.delete()
        } catch {
            throw error
        }
    }

    private func deleteAllFilesUnder(_ ref: StorageReference) async throws {
        let result = try await ref.listAll()
        for item in result.items { try? await item.delete() }
        for prefix in result.prefixes { try? await deleteAllFilesUnder(prefix) }
    }

}
