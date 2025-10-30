//
//  Cards.swift
//  Noi2
//
//  Created by Cristi Sandu on 23.10.2025.
//

import SwiftUI
import UIKit

// MARK: - Match / Join / State Cards

struct MatchCardEmpty: View {
    @Binding var joinCode: String
    var onCreate: () -> Void
    var onJoin: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let codeLength = 6
    private var isJoinValid: Bool {
        joinCode.count == codeLength
    }

    var body: some View {
        VStack(spacing: 16) {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onCreate()
            } label: {
                Label("Create a couple & get code", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(UITheme.accent)
            .accessibilityLabel("Create a couple and get code")

            Divider().opacity(0.2)

            HStack(spacing: 10) {
                TextField("Enter partner’s code", text: Binding(
                    get: { joinCode },
                    set: { newValue in
                        // Keep uppercase ASCII, strip spaces, limit length
                        let filtered = newValue
                            .uppercased()
                            .replacingOccurrences(of: " ", with: "")
                            .filter { "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains($0) }
                        joinCode = String(filtered.prefix(codeLength))
                    }
                ))
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .onSubmit {
                    guard isJoinValid else { return }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    onJoin()
                }
                .submitLabel(.join)
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("Partner code")

                Button("Join") {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    onJoin()
                }
                .buttonStyle(.bordered)
                .tint(UITheme.accent)
                .disabled(!isJoinValid)
                .accessibilityHint("Enter the 6-character code first")
            }
        }
        .padding(18)
        .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
        .accessibilityElement(children: .contain)
    }
}

struct CreatedWaitingCard: View {
    let code: String
    let members: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("Your code:")
                Text(code)
                    .font(.title2.weight(.bold)).monospaced()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
                    .accessibilityLabel("Your code \(code)")
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Copy code")
                }
                .buttonStyle(.bordered)
            }

            Text("Waiting for your partner to join… (\(members)/2)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
    }
}

struct JoinedPendingCard: View {
    let code: String
    let members: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Request sent", systemImage: "hourglass.circle.fill")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text("Partner’s code:")
                    .foregroundStyle(.secondary)
                Text(code)
                    .font(.subheadline.monospaced())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)
            }

            Text("Waiting for both of you to be connected… (\(members)/2)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
    }
}

struct CoupleCardMatched: View {
    let code: String
    let couple: Couple?
    @Binding var isEditing: Bool
    @Binding var picked: Date
    var onEdit: () -> Void
    var onCancelEdit: () -> Void
    var onSaveAnniv: () -> Void
    var onRemoveConnection: () -> Void

    @State private var askRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("Connection code:")
                    .foregroundStyle(.secondary)
                Text(code)
                    .font(.subheadline.monospaced())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
                Spacer()
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Edit anniversary").font(.subheadline.weight(.semibold))
                    DatePicker("Date", selection: $picked, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .accessibilityLabel("Anniversary date")
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
                if let date = couple?.anniversary {
                    HStack {
                        Text("Anniversary:")
                        Text(date.formatted(date: .long, time: .omitted))
                            .fontWeight(.semibold)
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            onEdit()
                        } label: { Label("Edit", systemImage: "pencil") }
                        .buttonStyle(.bordered)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set your anniversary").font(.subheadline.weight(.semibold))
                        DatePicker("Date", selection: $picked, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .accessibilityLabel("Anniversary date")
                        Button("Save anniversary") { onSaveAnniv() }
                            .buttonStyle(.borderedProminent)
                            .tint(UITheme.accent)
                    }
                }
            }

            Divider().opacity(0.15)

            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                askRemove = true
            } label: { Label("Remove connection", systemImage: "trash") }
            .buttonStyle(.bordered)
            .confirmationDialog("Remove connection?", isPresented: $askRemove, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { onRemoveConnection() }
                Button("Cancel", role: .cancel) { }
            }
        }
        .padding(18)
        .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
    }
}

// MARK: - Milestone / Stats

struct AnniversaryHeroCard: View {
    let anniversary: Date

    var body: some View {
        let days = Calendar.current.dateComponents([.day], from: anniversary, to: Date()).day ?? 0

        ZStack {
            LinearGradient(colors: [UITheme.accent, UITheme.accent.opacity(0.7)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            .opacity(0.90)

            VStack(spacing: 8) {
                Text("Together for")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))

                RingView(progress: progressToNextMilestone(fromDays: days))
                    .frame(width: 140, height: 140)
                    .overlay(
                        VStack(spacing: 0) {
                            Text("\(days)")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text("days")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    )
                    .padding(.bottom, 6)

                Text(anniversary.formatted(date: .long, time: .omitted))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .accessibilityLabel("Anniversary on \(anniversary.formatted(date: .complete, time: .omitted))")
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(radius: 8, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Together for \(days) days")
    }

    private func progressToNextMilestone(fromDays days: Int) -> Double {
        let milestones = [100, 200, 300, 365, 500, 700, 1000, 1500, 2000]
        let next = milestones.first(where: { $0 > days }) ?? (((days/500) + 2) * 500)
        let prev = milestones.reversed().first(where: { $0 <= days }) ?? 0
        let span = max(1, next - prev)
        return min(max(Double(days - prev) / Double(span), 0), 1)
    }
}

struct StatsGrid: View {
    let anniversary: Date

    var body: some View {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: anniversary, to: Date())
        let years = comps.year ?? 0
        let months = comps.month ?? 0
        let daysTotal = Calendar.current.dateComponents([.day], from: anniversary, to: Date()).day ?? 0
        let weeks = daysTotal / 7

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatPill(title: "Years",  value: "\(years)")
                StatPill(title: "Months", value: "\(months)")
            }
            HStack(spacing: 12) {
                StatPill(title: "Weeks", value: "\(weeks)")
                StatPill(title: "Days",  value: "\(daysTotal)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Time together")
        .accessibilityValue("\(years) years, \(months) months, \(weeks) weeks, \(daysTotal) days")
    }
}

struct NextMilestoneCard: View {
    let anniversary: Date

    var body: some View {
        let days = Calendar.current.dateComponents([.day], from: anniversary, to: Date()).day ?? 0
        let (label, remaining) = nextMilestone(fromDays: days)

        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "flag.checkered")
                .font(.title3.weight(.semibold))
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Next milestone")
                    .font(.subheadline.weight(.semibold))
                Text(label)
                    .font(.headline)
                    .foregroundStyle(UITheme.accent)
                Text("\(remaining) days to go")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next milestone: \(label)")
        .accessibilityValue("\(remaining) days to go")
    }

    private func nextMilestone(fromDays days: Int) -> (String, Int) {
        let milestones = [100, 200, 300, 365, 500, 700, 1000, 1500, 2000]
        let next = milestones.first(where: { $0 > days }) ?? (((days/500) + 1) * 500)
        let label = next == 365 ? "1 year" : "\(next) days"
        return (label, max(0, next - days))
    }
}
