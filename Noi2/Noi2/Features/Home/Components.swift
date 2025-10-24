//
//  Components.swift
//  Noi2
//
//  Created by Cristi Sandu on 23.10.2025.
//

import SwiftUI

// Section header with subtle motion
struct SectionHeader: View {
    var title: String
    var systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(UITheme.accent)
                .symbolEffect(.pulse)
            Text(title)
                .font(.headline)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

// Stats & ring reused
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
    }
}

struct RingView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().strokeBorder(.white.opacity(0.18), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [.white, .white.opacity(0.6), .white]),
                                    center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.uiSpring, value: progress)
        }
    }
}

// Love composer
struct LoveComposer: View {
    @State private var text = ""
    let onSend: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Send a short message…", text: $text)
                .textInputAutocapitalization(.sentences)
                .onChange(of: text) { _, new in
                    if new.count > 80 { text = String(new.prefix(80)) }
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Button {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onSend(trimmed)
                text = ""
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(UITheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
    }
}
