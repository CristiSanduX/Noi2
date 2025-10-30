//
//  Noi2App.swift
//  Noi2
//
//  Created by Cristi Sandu on 15.10.2025.
//

import SwiftUI

@main
struct Noi2App: App {
    // Bridge to UIKit delegates
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var auth = AuthViewModel()

    // Splash control
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView {
                        // Ensure a smooth fade out when Splash finishes its own animation
                        withAnimation(.easeInOut) { showSplash = false }
                    }
                    .transition(.opacity)
                } else {
                    // Inject the shared AuthViewModel from the root
                    ContentView(auth: auth)
                        .transition(.opacity)
                }
            }
            // Failsafe: if SplashView callback is not triggered for any reason, auto-dismiss after a short delay
            .task {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // ~1.5s
                if showSplash {
                    withAnimation(.easeInOut) { showSplash = false }
                }
            }
        }
    }
}
