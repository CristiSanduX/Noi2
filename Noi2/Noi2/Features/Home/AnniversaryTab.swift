//
//  AnniversaryTab.swift
//  Noi2
//
//  Created by Cristi Sandu on 23.10.2025.
//

import SwiftUI
import WidgetKit
import PhotosUI

struct AnniversaryTab: View {
    let couple: Couple?

    @Binding var isEditing: Bool
    @Binding var picked: Date

    let isUploadingWidgetPhoto: Bool

    // Callbacks
    var onEdit: () -> Void
    var onCancelEdit: () -> Void
    var onSaveAnniv: () -> Void
    var onPickWidgetImage: (UIImage) -> Void

    var body: some View {
        VStack(spacing: 22) {
            // MARK: - Photo section
            SectionHeader("Your photo", systemImage: "photo.on.rectangle.angled")

            CouplePhotoCard()

            WidgetPhotoPickerRow(
                isUploadingVM: isUploadingWidgetPhoto,
                onImagePicked: onPickWidgetImage
            )

            // MARK: - With anniversary set
            if let date = couple?.anniversary {
                SectionHeader("Milestones", systemImage: "flag.checkered")
                AnniversaryHeroCard(anniversary: date)
                StatsGrid(anniversary: date)
                NextMilestoneCard(anniversary: date)

                SectionHeader("Anniversary", systemImage: "calendar")
                GroupBox {
                    HStack {
                        Label("Anniversary", systemImage: "calendar")
                        Spacer()
                        Text(date.formatted(date: .long, time: .omitted))
                            .font(.body.weight(.semibold))
                    }
                    .padding(.vertical, 2)

                    if isEditing {
                        VStack(alignment: .leading, spacing: 12) {
                            DatePicker("Change date", selection: $picked, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .onChange(of: picked) { _, newValue in
                                    if newValue > Date() { picked = Date() }
                                }

                            HStack {
                                Button("Cancel", role: .cancel) { onCancelEdit() }
                                Spacer()
                                Button("Save") { onSaveAnniv() }
                                    .buttonStyle(.borderedProminent)
                                    .tint(UITheme.accent)
                            }
                        }
                        .transition(.opacity)
                    } else {
                        HStack {
                            Spacer()
                            Button {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                onEdit()
                            } label: {
                                Label("Edit anniversary", systemImage: "pencil")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .groupBoxStyle(.automatic)
                .padding(.top, 8)

            // MARK: - No anniversary yet
            } else {
                SectionHeader("Set your anniversary", systemImage: "sparkles")
                VStack(spacing: 16) {
                    DatePicker("Date", selection: $picked, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .onAppear {
                            if picked > Date() { picked = Date() }
                        }

                    Button("Save anniversary") { onSaveAnniv() }
                        .buttonStyle(.borderedProminent)
                        .tint(UITheme.accent)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.08)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

// MARK: - WidgetPhotoPickerRow (read-only busy din VM + busy local la import)
struct WidgetPhotoPickerRow: View {
    let isUploadingVM: Bool
    let onImagePicked: (UIImage) -> Void

    @State private var isImporting = false
    @State private var selection: PhotosPickerItem?

    private var isBusy: Bool { isImporting || isUploadingVM }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title3)
                .foregroundStyle(UITheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Widget photo").font(.headline)
                Text("Choose a photo to show on your Home widget.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            PhotosPicker(selection: $selection, matching: .images) {
                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Choose")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(UITheme.glassBG(), in: Capsule())
                }
            }
            .disabled(isBusy)
        }
        .padding(12)
        .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
        .onChange(of: selection) { _, newItem in
            guard let item = newItem, !isBusy else { return }
            isImporting = true
            Task {
                defer { isImporting = false }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    onImagePicked(img)
                }
            }
        }
    }
}
