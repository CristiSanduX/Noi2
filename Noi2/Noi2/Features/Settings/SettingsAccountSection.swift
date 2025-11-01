//
//  SettingsAccountSection.swift
//  Noi2
//
//  Created by Cristi Sandu on 01.11.2025.
//

import SwiftUI

struct SettingsAccountSection: View {
    @State private var showConfirm = false
    @State private var isDeleting = false
    @State private var errorText: String?

    var onDeleted: () -> Void = {}

    var body: some View {
        Section(header: Text("Account")) {
            Button(role: .destructive) {
                showConfirm = true
            } label: {
                Text("Delete Account")
            }
            .disabled(isDeleting)
            .confirmationDialog(
                "Delete account permanently?",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) { Task { await delete() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and personal data. This action cannot be undone.")
            }

            if let e = errorText {
                Text(e).foregroundColor(.red).font(.footnote)
            }
        }
    }

    private func delete() async {
        isDeleting = true
        do {
            try await AccountDeletionService.shared.deleteCurrentUser()
            onDeleted()
        } catch {
            errorText = error.localizedDescription
        }
        isDeleting = false
    }
}
