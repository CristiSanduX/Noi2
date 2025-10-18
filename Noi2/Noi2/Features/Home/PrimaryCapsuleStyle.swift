//
//  PrimaryCapsuleStyle.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import SwiftUI

struct PrimaryCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [
                        Color("AccentColor"),
                        Color("AccentColor").opacity(0.85)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(.white.opacity(configuration.isPressed ? 0.15 : 0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0.2 : 0.35),
                    radius: configuration.isPressed ? 8 : 16,
                    x: 0, y: configuration.isPressed ? 6 : 12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
