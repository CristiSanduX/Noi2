//
//  LastSentBar.swift
//  Noi2
//
//  Created by Cristi Sandu on 23.10.2025.
//


import SwiftUI

import Foundation

struct LastSent: Codable, Equatable {
    let text: String
    let date: Date
}

struct LastSentBar: View {
    let msg: LastSent
    var onResend: () -> Void
    var onEditResend: (_ newText: String) -> Void
    var onClear: () -> Void

    @State private var showEditor = false
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.headline)
                    .foregroundStyle(UITheme.accent)
                Text("Last message you sent")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(msg.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("“\(msg.text)”")
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button {
                    UIPasteboard.general.string = msg.text
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Button { onResend() } label: {
                    Label("Resend", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(UITheme.accent)

                Button {
                    draft = msg.text
                    showEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) { onClear() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                VStack(spacing: 12) {
                    TextField("Edit message", text: $draft, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(3, reservesSpace: true)
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    Spacer()
                }
                .padding(16)
                .navigationTitle("Edit & resend")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showEditor = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Send") {
                            let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            onEditResend(t)
                            showEditor = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(UITheme.accent)
                    }
                }
            }
        }
    }
}
