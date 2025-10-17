//
//  SharedLoveStore.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import Foundation

struct LoveNote: Codable, Equatable {
    let text: String
    let fromUid: String
    let fromName: String
    let updatedAt: Date
}

enum LoveStore {
    static let appGroupId = "group.ro.csx.Noi2.shared"
    private static let fileName = "love_note.json"

    private static var url: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)!
            .appendingPathComponent(fileName)
    }

    static func save(_ note: LoveNote) {
        do {
            let data = try JSONEncoder().encode(note)
            try data.write(to: url, options: .atomic)
        } catch {
            print("LoveStore save error:", error)
        }
    }

    static func load() -> LoveNote? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LoveNote.self, from: data)
    }
}
