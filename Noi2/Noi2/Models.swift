//
//  Models.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import Foundation
import FirebaseFirestore

struct UserProfile: Codable {
    var uid: String
    var displayName: String
    var email: String?
    var photoURL: String?
    var coupleId: String?
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
}

struct Couple: Codable, Identifiable {
    @DocumentID var id: String?
    var code: String
    var memberUids: [String]
    var anniversary: Date?
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
}
