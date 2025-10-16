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

@MainActor
final class AuthViewModel: ObservableObject {
    // UI state
    @Published var isSignedIn = false
    @Published var displayName: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        let user = Auth.auth().currentUser
        self.isSignedIn = (user != nil)
        self.displayName = user?.displayName
    }

    func signInWithGoogle() {
        guard !isLoading else { return }
        errorMessage = nil
        isLoading = true

        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.keyWindow?.rootViewController
        else {
            isLoading = false
            errorMessage = "Unable to find a valid window."
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: root) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                self.isLoading = false
                self.errorMessage = "Invalid Google token."
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                self.isSignedIn = true
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                self.displayName = authResult?.user.displayName
                print("Signed in as:", self.displayName ?? "(no name)")
            }
        }
    }

    func signOut() {
        do {
            GIDSignIn.sharedInstance.signOut()
            try Auth.auth().signOut()
            isSignedIn = false
            displayName = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// keyWindow helper
private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first { $0.isKeyWindow } }
}
