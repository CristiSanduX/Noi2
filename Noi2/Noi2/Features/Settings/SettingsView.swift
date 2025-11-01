//
//  SettingsView.swift
//  Noi2
//
//  Created by Cristi Sandu on 01.11.2025.
//


import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let onClose: () -> Void
    let onAccountDeleted: () -> Void

    var body: some View {
        NavigationStack {
            List {
                SettingsAccountSection(onDeleted: {
                    onAccountDeleted()
                    dismiss()
                })

                Section(header: Text("How to match with partner")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1) On Home tap **Connect with partner**.")
                        Text("2) One taps **Generate code**.")
                        Text("3) The other taps **Enter partner code**, types the code, then **Connect**.")
                        Text("Status: Waiting → Pending → Matched.")
                    }
                    .font(.subheadline)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onClose()
                        dismiss()
                    }
                }
            }
        }
    }
}
