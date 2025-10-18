//
//  WelcomeView.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import SwiftUI
import AuthenticationServices
import FirebaseAuth

struct WelcomeView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var animateIn = false
    @State private var showError = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Background adaptive gradient
            LinearGradient(
                colors: colorScheme == .dark
                ? [Color(.sRGB, red: 0.06, green: 0.07, blue: 0.12),
                   Color(.sRGB, red: 0.12, green: 0.13, blue: 0.22)]
                : [Color.white, Color(.sRGB, red: 0.98, green: 0.96, blue: 1.0)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Logo & Title
                VStack(spacing: 12) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .shadow(color: Color("AccentColor").opacity(0.5), radius: 12, y: 4)
                        .scaleEffect(animateIn ? 1 : 0.9)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateIn)

                    Text("Noi2")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .shadow(radius: 2)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.1), value: animateIn)

                    Text("A shared space for two souls 💫")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.15), value: animateIn)
                }

                Spacer()

                // Card with button
                VStack(spacing: 18) {
                    if auth.isLoading {
                        ProgressView("Connecting...")
                            .tint(Color("AccentColor"))
                            .font(.headline)
                    } else {
                        // MARK: - Google Button
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            auth.signInWithGoogle()
                        } label: {
                            HStack(spacing: 10) {
                                Image("GoogleG")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text("Sign in with Google")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryCapsuleStyle())

                        // MARK: - Apple Button
                        AppleSignInButton()
                            .padding(.top, 8)
                            .environmentObject(auth)
                    }

                    if let error = auth.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Text("By continuing, you agree to our **Terms of Use** and **Privacy Policy**.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(24)
                .background(
                    colorScheme == .dark
                    ? AnyShapeStyle(.ultraThinMaterial)
                    : AnyShapeStyle(Color.white.opacity(0.85)),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
                .padding(.horizontal, 28)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 30)
                .animation(.easeOut(duration: 0.7).delay(0.2), value: animateIn)

                Spacer(minLength: 60)
            }
            .onAppear { animateIn = true }
        }
    }
}

struct AppleSignInButton: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var currentNonce: String?

    var body: some View {
        SignInWithAppleButton(.signIn,
            onRequest: { request in
                let nonce = randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(nonce)
            },
            onCompletion: handle
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 49)
        .frame(maxWidth: .infinity)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
        .padding(.horizontal, 2)
    }

    private func handle(result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            DispatchQueue.main.async { auth.isLoading = false }
            print("Apple sign-in failed:", error)

        case .success(let authResult):
            guard
                let appleIDCredential = authResult.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = appleIDCredential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                DispatchQueue.main.async { auth.isLoading = false }
                print("Apple sign-in: token/nonce missing")
                return
            }

            DispatchQueue.main.async { auth.isLoading = true }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            if let user = Auth.auth().currentUser {
                user.link(with: credential) { _, error in
                    if let error = error { print("Link Apple failed:", error) }
                    DispatchQueue.main.async { auth.isLoading = false }
                }
            } else {
                Auth.auth().signIn(with: credential) { result, error in
                    if let error = error {
                        print("Firebase Apple sign-in error:", error)
                        DispatchQueue.main.async { auth.isLoading = false }
                        return
                    }

                    if let fullName = appleIDCredential.fullName,
                       let user = result?.user {
                        let name = [fullName.givenName, fullName.familyName]
                            .compactMap { $0 }.joined(separator: " ")
                        if !name.isEmpty {
                            let change = user.createProfileChangeRequest()
                            change.displayName = name
                            change.commitChanges(completion: nil)
                        }
                    }

                    DispatchQueue.main.async { auth.isLoading = false }
                }
            }
        }
    }
}

