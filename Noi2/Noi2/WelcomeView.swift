//
//  WelcomeView.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import SwiftUI

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
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            auth.signInWithGoogle()
                        } label: {
                            HStack(spacing: 10) {
                                Image("GoogleG")
                                    .resizable()
                                    .frame(width: 22, height: 22)
                                Text("Continue with Google")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryCapsuleStyle())
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
