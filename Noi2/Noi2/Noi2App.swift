//
//  Noi2App.swift
//  Noi2
//
//  Created by Cristi Sandu on 15.10.2025.
//

import SwiftUI
import UIKit
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        
        // configure Google Sign-In client
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            print("GIDClientID configured successfully")
        } else {
            print("Could not load clientID from Firebase config")
        }
        
        return true
    }
}

@main
struct Noi2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView {
                        showSplash = false
                    }
                    .transition(.opacity)
                } else {
                    ContentView()
                        .transition(.opacity)
                }
            }
        }
    }
}
