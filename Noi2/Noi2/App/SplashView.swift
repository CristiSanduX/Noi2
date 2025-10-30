//
//  SplashView.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import SwiftUI
import UIKit

struct SplashView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var appear = false
    @State private var beat = false
    @State private var flicker = false
    @State private var fadeOut = false
    @State private var finishedCalled = false

    var body: some View {
        ZStack {
            // Background gradient
            RadialGradient(
                colors: [
                    Color("AppBackground"),
                    Color("AppBackground").opacity(0.95)
                ],
                center: .center,
                startRadius: 10,
                endRadius: 700
            )
            .ignoresSafeArea()

            // Soft glow behind the logo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color("AccentColor").opacity(0.30), .clear],
                        center: .center,
                        startRadius: 1,
                        endRadius: 220
                    )
                )
                .frame(width: 340, height: 340)
                .blur(radius: 40)
                .opacity(appear ? 1 : 0)

            VStack(spacing: 18) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .scaleEffect(reduceMotion ? 1.0 : (beat ? 1.06 : 0.94))
                    .rotationEffect(reduceMotion ? .degrees(0) : .degrees(flicker ? 0.8 : -0.8), anchor: .top)
                    .shadow(
                        color: Color("AccentColor").opacity(reduceMotion ? 0.35 : 0.55),
                        radius: reduceMotion ? 12 : (beat ? 22 : 8),
                        x: 0, y: 0
                    )
                    // Run pulsing/tilt animations only when motion is allowed
                    .animation(reduceMotion ? .default : .easeInOut(duration: 0.68).repeatForever(autoreverses: true), value: beat)
                    .animation(reduceMotion ? .default : .easeInOut(duration: 0.24).repeatForever(autoreverses: true), value: flicker)

                Text("Share your story, together.")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 8)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: appear)
            }
            .opacity(fadeOut ? 0 : 1)
        }
        .allowsHitTesting(false)
        .onAppear(perform: start)
        .onChange(of: scenePhase) { phase in
            // Pause heavy animations when the app goes inactive/background
            if reduceMotion { return }
            switch phase {
            case .active:
                if appear && !fadeOut {
                    beat = true
                    flicker = true
                }
            default:
                beat = false
                flicker = false
            }
        }
    }

    // MARK: - Flow

    private func start() {
        // Light haptic (non-blocking)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()

        appear = true

        if !reduceMotion {
            beat = true
            flicker = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.5)) {
                fadeOut = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                callFinishedOnce()
            }
        }
    }

    private func callFinishedOnce() {
        guard !finishedCalled else { return }
        finishedCalled = true
        onFinished()
    }
}

#Preview {
    SplashView { }
}
