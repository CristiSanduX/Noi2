//
//  PrimaryCapsuleStyle.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import SwiftUI

struct PrimaryCapsuleStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            // Use system adaptive color for text contrast safety
            .foregroundStyle(colorScheme == .dark ? Color.white : Color.white)
            .background(
                LinearGradient(
                    colors: gradientColors(pressed: configuration.isPressed),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(configuration.isPressed ? 0.15 : 0.25), lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.2 : 0.35),
                radius: configuration.isPressed ? 6 : 14,
                x: 0, y: configuration.isPressed ? 4 : 8
            )
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.97 : 1.0))
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.2),
                value: configuration.isPressed
            )
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Helpers
    private func gradientColors(pressed: Bool) -> [Color] {
        let accent = Color("AccentColor")
        return pressed
            ? [accent.opacity(0.8), accent.opacity(0.65)]
            : [accent, accent.opacity(0.85)]
    }
}
