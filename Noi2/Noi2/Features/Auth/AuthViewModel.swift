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
    // MARK: - UI state
    @Published var isSignedIn: Bool = false
    @Published var displayName: String? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Auth state listener
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        // stare inițială
        let user = Auth.auth().currentUser
        self.isSignedIn = (user != nil)
        self.displayName = user?.displayName

        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.isSignedIn = (user != nil)
            self.displayName = user?.displayName
            self.isLoading = false
        }
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    // MARK: - Google
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

                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                self.displayName = authResult?.user.displayName
            }
        }
    }

    // MARK: - Sign out
    func signOut() {
        do {
            GIDSignIn.sharedInstance.signOut()
            try Auth.auth().signOut()
            // listener-ul va seta automat isSignedIn = false
            self.displayName = nil
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - UIWindow helper
private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first { $0.isKeyWindow } }
}
