//
//  SharedWidgetStore.swift
//  Noi2
//
//  Created by Cristi Sandu on 24.10.2025.
//

import UIKit
import WidgetKit

enum SharedWidgetStore {
    // MARK: - Constants
    static let appGroupId = "group.ro.csx.Noi2x.shared"
    private static let anniversaryKey = "widget_anniversary_iso"
    private static let photoFilename = "widget_photo.jpg"

    // MARK: - Anniversary (date)
    static func saveAnniversary(_ date: Date) {
        guard let ud = UserDefaults(suiteName: appGroupId) else { return }
        let iso = ISO8601DateFormatter().string(from: date)
        ud.set(iso, forKey: anniversaryKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func loadAnniversary() -> Date? {
        guard let ud = UserDefaults(suiteName: appGroupId),
              let iso = ud.string(forKey: anniversaryKey)
        else { return nil }
        return ISO8601DateFormatter().date(from: iso)
    }

    // MARK: - Widget Photo (image)
    static func saveWidgetPhoto(_ image: UIImage, compression: CGFloat = 0.9) {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        else { return }

        let url = container.appendingPathComponent(photoFilename)
        guard let data = image.jpegData(compressionQuality: compression) else { return }

        do {
            try data.write(to: url, options: [.atomic])
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("[ERR] saveWidgetPhoto failed:", error.localizedDescription)
        }
    }

    static func loadWidgetPhoto() -> UIImage? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        else { return nil }

        let url = container.appendingPathComponent(photoFilename)
        guard let data = try? Data(contentsOf: url),
              let img = UIImage(data: data)
        else { return nil }
        return img
    }

    // MARK: - Cleanup (optional)
    static func clearWidgetPhoto() {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        else { return }

        let url = container.appendingPathComponent(photoFilename)
        try? FileManager.default.removeItem(at: url)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
