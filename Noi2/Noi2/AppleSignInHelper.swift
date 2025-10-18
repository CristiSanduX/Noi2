
//
//  AppleSignInHelper.swift
//  Noi2
//
//  Created by Cristi Sandu on 17.10.2025.
//

import Foundation
import CryptoKit

func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        var randoms: [UInt8] = (0..<16).map { _ in
            var random: UInt8 = 0
            let err = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if err != errSecSuccess { fatalError("Unable to generate nonce.") }
            return random
        }

        randoms.forEach { random in
            if remainingLength == 0 { return }
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }

    return result
}

func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}
