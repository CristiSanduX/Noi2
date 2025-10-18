//
//  HomeView.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    let displayName: String?
    let onSignOut: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    if vm.isLoading { ProgressView().tint(Color("AccentColor")) }

                    switch vm.state {
                    case .noCouple:
                        MatchCardEmpty(
                            joinCode: $vm.joinCode,
                            onCreate: { Task { await vm.generateAndCreateCouple() } },
                            onJoin: { Task { await vm.joinCoupleByCode() } }
                        )

                    case .createdWaiting(let code, let members):
                        CreatedWaitingCard(code: code, members: members)

                    case .joinedPending(let code, let members):
                        JoinedPendingCard(code: code, members: members)

                    case .matched(let code):
                        CoupleCardMatched(
                            code: code,
                            couple: vm.couple,
                            isEditing: $vm.isEditingAnniversary,
                            picked: $vm.pickedAnniversary,
                            onEdit: { vm.startEditingAnniversary() },
                            onCancelEdit: { vm.cancelEditingAnniversary() },
                            onSaveAnniv: { Task { await vm.saveAnniversary() } },
                            onRemoveConnection: { Task { await vm.leaveCouple() } }
                        )

                        LoveComposer { message in
                            vm.sendLoveMessage(message)
                        }
                    }

                    if let err = vm.errorMessage, !err.isEmpty {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.top, 8)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Noi2")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") { onSignOut() }
                }
            }
            .task { await vm.load() }
            .onAppear {
                vm.currentUserName = displayName ?? "Me"
                if case .matched = vm.state {
                    vm.startMessageSync()
                }
            }
            .onChange(of: vm.state) { _, newValue in
                switch newValue {
                case .matched:
                    vm.startMessageSync()
                default:
                    vm.stopMessageSync()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    if case .matched = vm.state {
                        vm.startMessageSync()
                    }
                case .inactive, .background:
                    vm.stopMessageSync()
                @unknown default:
                    break
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color("AccentColor"))
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome, \(displayName ?? "there")")
                    .font(.headline)
                Text("Let’s connect your accounts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Cards

private struct MatchCardEmpty: View {
    @Binding var joinCode: String
    var onCreate: () -> Void
    var onJoin: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Match with your partner")
                .font(.headline)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onCreate()
            } label: {
                Label("Create a couple & get code", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("AccentColor"))

            Divider().opacity(0.2)

            HStack {
                TextField("Enter partner’s code", text: $joinCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                Button("Join") {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    onJoin()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CreatedWaitingCard: View {
    let code: String
    let members: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Invite your partner", systemImage: "paperplane.circle.fill")
                .font(.headline)
                .foregroundStyle(Color("AccentColor"))

            HStack {
                Text("Your code:")
                Text(code)
                    .font(.title2).bold().monospaced()
                    .padding(6)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: { Image(systemName: "doc.on.doc") }
            }

            Text("Waiting for your partner to join… (\(members)/2)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct JoinedPendingCard: View {
    let code: String
    let members: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Request sent", systemImage: "hourglass.circle.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Partner’s code: \(code)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Waiting for both of you to be connected… (\(members)/2)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CoupleCardMatched: View {
    let code: String
    let couple: Couple?
    @Binding var isEditing: Bool
    @Binding var picked: Date
    var onEdit: () -> Void
    var onCancelEdit: () -> Void
    var onSaveAnniv: () -> Void
    var onRemoveConnection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("You’re matched!", systemImage: "link.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color("AccentColor"))
                Spacer()
                Text(code)
                    .font(.subheadline.monospaced())
                    .padding(6)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Edit anniversary").font(.subheadline.weight(.semibold))
                    DatePicker("Date", selection: $picked, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    HStack {
                        Button("Cancel", role: .cancel) { onCancelEdit() }
                        Spacer()
                        Button("Save") { onSaveAnniv() }
                            .buttonStyle(.borderedProminent)
                            .tint(Color("AccentColor"))
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
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set your anniversary").font(.subheadline.weight(.semibold))
                        DatePicker("Date", selection: $picked, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                        Button("Save anniversary") { onSaveAnniv() }
                            .buttonStyle(.borderedProminent)
                            .tint(Color("AccentColor"))
                    }
                }
            }

            Divider().opacity(0.15)

            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                onRemoveConnection()
            } label: {
                Label("Remove connection", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct LoveComposer: View {
    @State private var text = ""
    let onSend: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Send a short message…", text: $text)
                .textInputAutocapitalization(.sentences)
                .onChange(of: text) { _, new in
                    if new.count > 80 { text = String(new.prefix(80)) }
                }
            Button("Send") {
                let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                onSend(t); text = ""
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
