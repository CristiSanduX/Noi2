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

    @State private var appear = false
    @State private var beat = false
    @State private var flameFlicker = false
    @State private var fadeOut = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [
                Color("AppBackground"),
                Color("AppBackground").opacity(0.95)
            ], center: .center, startRadius: 10, endRadius: 700)
            .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(colors: [
                        Color("AccentColor").opacity(0.30),
                        .clear
                    ], center: .center, startRadius: 1, endRadius: 220)
                )
                .frame(width: 340, height: 340)
                .blur(radius: 40)
                .opacity(appear ? 1 : 0)

            VStack(spacing: 18) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .scaleEffect(beat ? 1.06 : 0.94)
                    .rotationEffect(.degrees(flameFlicker ? 0.8 : -0.8), anchor: .top)
                    .shadow(color: Color("AccentColor").opacity(0.55),
                            radius: beat ? 22 : 8, x: 0, y: 0)
                    .animation(.easeInOut(duration: 0.68).repeatForever(autoreverses: true), value: beat)
                    .animation(.easeInOut(duration: 0.24).repeatForever(autoreverses: true), value: flameFlicker)

                Text("Share your story, together.")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 8)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: appear)
            }
            .opacity(fadeOut ? 0 : 1)
        }
        .onAppear {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()

            appear = true
            beat = true
            flameFlicker = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    fadeOut = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    onFinished()
                }
            }
        }
    }
}
