//
//  AnniversaryTab.swift
//  Noi2
//
//  Created by Cristi Sandu on 23.10.2025.
//


import SwiftUI
import WidgetKit

struct AnniversaryTab: View {
    let couple: Couple?
    @Binding var isEditing: Bool
    @Binding var picked: Date
    var onEdit: () -> Void
    var onCancelEdit: () -> Void
    var onSaveAnniv: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            SectionHeader("Your photo", systemImage: "photo.on.rectangle.angled")
            CouplePhotoCard()

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
                            DatePicker("Change date", selection: $picked, displayedComponents: .date)
                                .datePickerStyle(.graphical)
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

            } else {
                SectionHeader("Set your anniversary", systemImage: "sparkles")
                VStack(spacing: 16) {
                    DatePicker("Date", selection: $picked, displayedComponents: .date)
                        .datePickerStyle(.graphical)

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
    }
}
