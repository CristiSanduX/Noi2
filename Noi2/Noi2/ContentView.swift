//
//  ContentView.swift
//  Noi2
//
//  Created by Cristi Sandu on 15.10.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthViewModel()

    var body: some View {
        Group {
            if auth.isSignedIn {
                HomeView(displayName: auth.displayName, onSignOut: auth.signOut)
            } else {
                WelcomeView().environmentObject(auth)
            }
        }
        .animation(.easeInOut, value: auth.isSignedIn)
    }
}

private struct HomeView: View {
    let displayName: String?
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome, \(displayName ?? "user") ❤️")
                .font(.title2).fontWeight(.semibold)
            Button("Sign out", action: onSignOut)
                .buttonStyle(PrimaryCapsuleStyle())
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
