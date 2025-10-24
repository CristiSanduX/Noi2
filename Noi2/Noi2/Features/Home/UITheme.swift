//
//  UITheme.swift
//  Noi2
//
//  Created by Cristi Sandu on 23.10.2025.
//


import SwiftUI

// Global look & feel
enum UITheme {
    static let accent = Color("AccentColor")

    // Soft glass card
    static func glassBG(corner: CGFloat = 18) -> some ShapeStyle {
        AnyShapeStyle(.ultraThinMaterial)
    }

    // Primary gradient (animated in views)
    static var gradientColors: [Color] {
        [accent, accent.opacity(0.75), accent.opacity(0.55)]
    }
}

// Reusable styles
struct PrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(UITheme.accent.opacity(configuration.isPressed ? 0.85 : 1), in: Capsule())
            .foregroundStyle(.white)
            .shadow(color: UITheme.accent.opacity(0.25), radius: 12, y: 6)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// Simple spring animation helper
extension Animation {
    static var uiSpring: Animation { .spring(response: 0.5, dampingFraction: 0.82) }
}
