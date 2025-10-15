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
        VStack(spacing: 20) {
            if auth.isSignedIn {
                Text("Salut, \(auth.displayName ?? "user")! ❤️")
                    .font(.title3)
                Button("Sign out") {
                    auth.signOut()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    auth.signInWithGoogle()
                } label: {
                    Label("Continue with Google", systemImage: "g.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}


#Preview {
    ContentView()
}
