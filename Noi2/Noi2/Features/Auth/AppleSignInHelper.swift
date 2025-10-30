//
//  AppleSignInHelper.swift
//  Noi2
//
//  Created by Cristi Sandu on 17.10.2025.
//

import Foundation
import CryptoKit

/// Generates a cryptographically secure random nonce string for Sign in with Apple.
func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0, "Nonce length must be > 0")

    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    var result = String()
    result.reserveCapacity(length)

    while result.count < length {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        if status != errSecSuccess {
            let fallback = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            result.append(contentsOf: fallback.prefix(length - result.count))
            break
        }

        for b in bytes {
            if result.count == length { break }
            if b < charset.count { result.append(charset[Int(b)]) }
        }
    }

    return result
}

/// Hex-encodes the SHA-256 of a string (lowercase).
func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.map { String(format: "%02x", $0) }.joined()
}
