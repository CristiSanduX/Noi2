//
//  ContentView.swift
//  Noi2
//
//  Created by Cristi Sandu on 15.10.2025.

//

import SwiftUI

enum AppRoute: Equatable {
    case signedOut
    case connecting
    case home
}

struct ContentView: View {
    @StateObject var auth: AuthViewModel

    @State private var route: AppRoute = .signedOut
    @State private var connectingTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            switch route {
            case .signedOut:
                WelcomeView()

            case .connecting:
                ConnectingView()
                    .transition(.opacity)

            case .home:
                HomeView(displayName: auth.displayName, onSignOut: auth.signOut)
                    .transition(.opacity)
            }
        }
        .environmentObject(auth)
        .animation(.easeInOut, value: route)
        .onAppear { bootstrapRoute() }
        .onChange(of: auth.isSignedIn) { signedIn in
            handleAuthChange(signedIn: signedIn)
        }
    }

    // MARK: - Flow

    private func bootstrapRoute() {
        route = auth.isSignedIn ? .home : .signedOut
    }

    private func handleAuthChange(signedIn: Bool) {
        connectingTask?.cancel()
        connectingTask = nil

        guard signedIn else {
            route = .signedOut
            return
        }

        route = .connecting
        connectingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000) // ~1.8s
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                route = .home
            }
        }
    }
}
