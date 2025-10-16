//
//  FirestoreService.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

enum FirestoreService {
    static let db = Firestore.firestore()

    static var users: CollectionReference { db.collection("users") }
    static var couples: CollectionReference { db.collection("couples") }

    static func bootstrapCurrentUser() async throws -> UserProfile {
        guard let u = Auth.auth().currentUser else { throw NSError(domain: "Auth", code: 401) }
        let ref = users.document(u.uid)

        let data: [String: Any] = [
            "uid": u.uid,
            "displayName": u.displayName ?? "User",
            "email": u.email as Any,
            "photoURL": u.photoURL?.absoluteString as Any,
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await ref.setData(data, merge: true)

        let snap = try await ref.getDocument()
        return try snap.data(as: UserProfile.self)
    }

    static func setUserCouple(uid: String, coupleId: String?) async throws {
        try await users.document(uid).setData([
            "coupleId": coupleId as Any,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    static func createCouple(ownerUid: String, code: String) async throws -> String {
        let ref = couples.document() // auto-id
        try await ref.setData([
            "code": code,
            "memberUids": [ownerUid],
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
    }

    static func findCoupleBy(code: String) async throws -> Couple? {
        let qs = try await couples.whereField("code", isEqualTo: code.uppercased()).limit(to: 1).getDocuments()
        guard let doc = qs.documents.first else { return nil }
        return try doc.data(as: Couple.self)
    }

    static func joinCouple(coupleId: String, uid: String) async throws {
        let ref = couples.document(coupleId)
        try await ref.updateData([
            "memberUids": FieldValue.arrayUnion([uid]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    static func setAnniversary(coupleId: String, date: Date) async throws {
        try await couples.document(coupleId).updateData([
            "anniversary": Timestamp(date: date),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    static func removeMember(coupleId: String, uid: String) async throws {
        try await couples.document(coupleId).updateData([
            "memberUids": FieldValue.arrayRemove([uid]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    static func deleteCoupleIfEmpty(coupleId: String) async throws {
        let doc = try await couples.document(coupleId).getDocument()
        if let data = doc.data(), let members = data["memberUids"] as? [String], members.isEmpty {
            try await couples.document(coupleId).delete()
        }
    }

}
