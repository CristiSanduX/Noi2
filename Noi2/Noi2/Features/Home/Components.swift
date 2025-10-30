//
//  Components.swift
//  Noi2
//
//  Created by Cristi Sandu on 23.10.2025.
//

import SwiftUI
import UIKit

// MARK: - Section header with subtle motion

struct SectionHeader: View {
    var title: String
    var systemImage: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(UITheme.accent)
                .if(!reduceMotion) { view in
                    view.symbolEffect(.pulse)
                }

            Text(title)
                .font(.headline)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

// MARK: - Stats pill

struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Ring progress view

struct RingView: View {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var clamped: Double { min(max(progress, 0.0), 1.0) }

    var body: some View {
        ZStack {
            Circle().strokeBorder(.white.opacity(0.18), lineWidth: 10)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.white, .white.opacity(0.6), .white]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .uiSpring, value: clamped)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(clamped * 100)) percent")
    }
}

// MARK: - Love composer

struct LoveComposer: View {
    @State private var text = ""
    let onSend: (String) -> Void

    private let maxLength = 80

    var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("Send a short message…", text: $text, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .onChange(of: text) { _, new in
                    if new.count > maxLength { text = String(new.prefix(maxLength)) }
                }
                .onSubmit(sendIfValid)
                .submitLabel(.send)
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    HStack {
                        Spacer()
                        Text("\(text.count)/\(maxLength)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                            .accessibilityHidden(true)
                    }
                )

            Button(action: sendIfValid) {
                Image(systemName: "paperplane.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(UITheme.accent)
                    .accessibilityLabel("Send")
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty)
        }
        .padding(12)
        .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
        .accessibilityHint("Compose a short message and press Send.")
    }

    private func sendIfValid() {
        let t = trimmed
        guard !t.isEmpty else { return }
        onSend(t)
        text = ""
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

// MARK: - Lightweight conditional modifier

private extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
