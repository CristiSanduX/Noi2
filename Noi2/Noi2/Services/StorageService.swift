//
//  StorageService.swift
//  Noi2
//
//  Created by Cristi Sandu on 24.10.2025.
//


import FirebaseStorage
import UIKit

enum StorageService {
    private static var root: StorageReference { Storage.storage().reference() }

    static func uploadWidgetPhoto(coupleId: String, image: UIImage,
                                  jpegQuality: CGFloat = 0.9) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: jpegQuality) else {
            throw NSError(domain: "StorageService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "JPEG encode failed"])
        }
        let ref = root.child("couples/\(coupleId)/widget_photo.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL()
    }

    static func downloadData(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}
