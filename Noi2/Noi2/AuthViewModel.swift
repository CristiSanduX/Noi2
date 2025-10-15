//
//  AuthViewModel.swift
//  Noi2
//
//  Created by Cristi Sandu on 15.10.2025.
//


import Foundation
import FirebaseAuth
import GoogleSignIn
import UIKit

final class AuthViewModel: ObservableObject {
    @Published var isSignedIn = false
    @Published var displayName: String?

    init() {
        self.isSignedIn = Auth.auth().currentUser != nil
        self.displayName = Auth.auth().currentUser?.displayName
    }

    func signInWithGoogle() {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.keyWindow?.rootViewController
        else { return }

        GIDSignIn.sharedInstance.signIn(withPresenting: root) { result, error in
            if let error = error {
                print("Google Sign-In error:", error.localizedDescription)
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else { return }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                if let error = error {
                    print("Firebase Auth error:", error.localizedDescription)
                    return
                }
                self?.isSignedIn = true
                self?.displayName = authResult?.user.displayName
                print("Signed in as:", self?.displayName ?? "(no name)")
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            isSignedIn = false
            displayName = nil
        } catch {
            print("Sign out error:", error.localizedDescription)
        }
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first { $0.isKeyWindow } }
}
