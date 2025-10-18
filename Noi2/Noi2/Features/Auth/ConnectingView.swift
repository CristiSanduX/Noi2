//
//  ConnectingView.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import SwiftUI
import UIKit

struct ConnectingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("AppBackground"), Color("AppBackground").opacity(0.92)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                PulsingHeart(size: 86)

                Text("Connecting your hearts…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
        }
        .task {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting your hearts")
    }
}

private struct PulsingHeart: View {
    let size: CGFloat
    @State private var beat = false
    @State private var glow = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [Color("AccentColor").opacity(0.28), .clear],
                                   center: .center, startRadius: 4, endRadius: size * 1.8)
                )
                .blur(radius: 24)
                .opacity(glow ? 1 : 0.6)

            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(Color("AccentColor"))
                .scaleEffect(beat ? 1.08 : 0.92)
                .shadow(color: Color("AccentColor").opacity(0.55),
                        radius: beat ? 18 : 8, x: 0, y: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.68).repeatForever(autoreverses: true)) {
                beat.toggle()
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glow.toggle()
            }
        }
    }
}
