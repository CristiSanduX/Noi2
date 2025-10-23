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
// App/Noi2App.swift
import SwiftUI

