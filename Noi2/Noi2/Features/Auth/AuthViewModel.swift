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

    // MARK: - Listener
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        // Bootstrap initial state from cached Firebase user
        let user = Auth.auth().currentUser
        self.isSignedIn = (user != nil)
        self.displayName = user?.displayName

        // Keep UI in sync with Firebase session changes
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

    // MARK: - Google Sign-In
    func signInWithGoogle() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        guard let presenter = Self.topMostViewController() else {
            isLoading = false
            errorMessage = "Unable to find a valid window."
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { [weak self] result, error in
            guard let self else { return }

            // Early exit on user cancel or error
            if let error = error as NSError? {
                self.isLoading = false
                if error.domain == kGIDSignInErrorDomain && error.code == GIDSignInError.canceled.rawValue {
                    self.errorMessage = nil
                } else {
                    self.errorMessage = "Google Sign-In failed. Please try again."
                }
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
                guard let self else { return }
                self.isLoading = false

                if let error = error {
                    // Do not surface raw errors to end users
                    self.errorMessage = "Sign-In could not be completed. Please try again."
                    #if DEBUG
                    print("[Auth] Firebase signIn error:", error.localizedDescription)
                    #endif
                    return
                }

                // Light haptic feedback on success
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()

                self.displayName = authResult?.user.displayName
            }
        }
    }

    // MARK: - Sign out
    func signOut() {
        do {
            // Sign out of Google first to clear browser/session state, then Firebase
            GIDSignIn.sharedInstance.signOut()
            try Auth.auth().signOut()

            // Listener will flip isSignedIn = false; clean up local UI state
            self.displayName = nil
            self.errorMessage = nil
            self.isLoading = false
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        } catch {
            self.errorMessage = "Could not sign out. Please try again."
            #if DEBUG
            print("[Auth] signOut error:", error.localizedDescription)
            #endif
        }
    }
}

// MARK: - Presenter helper
private extension AuthViewModel {
    static func topMostViewController() -> UIViewController? {
        // Find the active scene's key window
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let window = scene.windows.first(where: { $0.isKeyWindow }),
            var top = window.rootViewController
        else { return nil }

        while let presented = top.presentedViewController {
            top = presented
        }

        if let nav = top as? UINavigationController {
            top = nav.visibleViewController ?? nav
        } else if let tab = top as? UITabBarController {
            top = tab.selectedViewController ?? tab
        }

        return top
    }
}
