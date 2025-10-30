//
//  LastSentBar.swift
//  Noi2
//
//  Created by Cristi Sandu on 23.10.2025.

//

import SwiftUI
import Foundation
import UIKit

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
    @State private var showDeleteConfirm = false

    // Keep this aligned with the ViewModel’s limit
    private let maxLength = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.headline)
                    .foregroundStyle(UITheme.accent)
                    .accessibilityHidden(true)

                Text("Last message you sent")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(msg.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Sent on \(msg.date.formatted(date: .complete, time: .shortened))")
            }

            Text("“\(msg.text)”")
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .accessibilityLabel("Message: \(msg.text)")

            HStack(spacing: 8) {
                // Copy
                Button {
                    UIPasteboard.general.string = msg.text
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Copy message")

               

                // Edit & resend
                Button {
                    draft = msg.text
                    showEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Edit and resend message")

                Spacer()

                // Clear with confirmation
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Clear saved message")
                .confirmationDialog("Clear last sent message?",
                                    isPresented: $showDeleteConfirm,
                                    titleVisibility: .visible) {
                    Button("Delete", role: .destructive) { onClear() }
                    Button("Cancel", role: .cancel) { }
                }
            }
        }
        .padding(14)
        .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
        .sheet(isPresented: $showEditor) { editorSheet }
        .accessibilityElement(children: .contain)
        .accessibilityHint("You can copy, resend, edit, or clear the last message.")
    }

    // MARK: - Editor sheet

    private var editorSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Edit message", text: Binding(
                    get: { draft },
                    set: { newValue in
                        // Enforce max length while typing
                        draft = String(newValue.prefix(maxLength))
                    }
                ), axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .lineLimit(3, reservesSpace: true)
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Character counter
                HStack {
                    Spacer()
                    Text("\(draft.count)/\(maxLength)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .accessibilityHidden(true)
                }

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
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(UITheme.accent)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
