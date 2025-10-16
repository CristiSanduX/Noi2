//
//  ContentView.swift
//  Noi2
//
//  Created by Cristi Sandu on 15.10.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthViewModel()
    @State private var showConnecting = false

    var body: some View {
        ZStack {
            if auth.isSignedIn {
                if showConnecting {
                    ConnectingView()
                        .transition(.opacity)
                } else {
                    HomeView(displayName: auth.displayName, onSignOut: auth.signOut)
                        .transition(.opacity)
                }
            } else {
                WelcomeView()
                    .environmentObject(auth)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: auth.isSignedIn)
        .onChange(of: auth.isSignedIn) { signedIn in
            guard signedIn else { return }
            showConnecting = true
            // mic delay pentru „connecting…”
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showConnecting = false
                }
            }
        }
    }
}

private struct HomeView: View {
    let displayName: String?
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Welcome, \(displayName ?? "there") ❤️")
                    .font(.title2).fontWeight(.semibold)
                Button("Sign out", action: onSignOut)
                    .buttonStyle(.borderedProminent)
                    .tint(Color("AccentColor"))
            }
            .padding()
            .navigationTitle("Noi2")
        }
    }
}

#Preview {
    ContentView()
}
