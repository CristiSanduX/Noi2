//
//  HomeView.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import SwiftUI
import UIKit
import PhotosUI
import FirebaseAuth


struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    let displayName: String?
    let onSignOut: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Int = 0
    
  



    var body: some View {
        TabView(selection: $selectedTab) {

            // TAB 1: HOME
            NavigationStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 26) {
                        HeaderCard(displayName: displayName)

                        if vm.isLoading {
                            ProgressView().tint(UITheme.accent)
                        }

                        // Render în funcție de starea curentă
                        stateView()

                        if let err = vm.errorMessage, !err.isEmpty {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 52)
                }
                .navigationBarItems(trailing:
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        onSignOut()
                    }, label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    })
                )




                .background(staticBackground)
                .task { await vm.load() }
                .onAppear {
                    vm.currentUserName = displayName ?? "Me"
                    if case .matched(let code) = vm.state {
                        vm.startMessageSync()
                        Task { await vm.startCloudKitSync(coupleId: code) }
                    }
                }
                .onChange(of: vm.state) { newValue in
                    switch newValue {
                    case .matched(let code):
                        vm.startMessageSync()
                        Task { await vm.startCloudKitSync(coupleId: code) }
                    default:
                        vm.stopMessageSync()
                    }
                }
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        if case .matched(let code) = vm.state {
                            vm.startMessageSync()
                            Task { await vm.startCloudKitSync(coupleId: code) }
                        }
                    case .inactive, .background:
                        vm.stopMessageSync()
                    @unknown default: break
                    }
                }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)

            // TAB 2: ANNIVERSARY
            NavigationStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        AnniversaryTab(
                            couple: vm.couple,
                            isEditing: $vm.isEditingAnniversary,
                            picked: $vm.pickedAnniversary,
                            onEdit: { vm.startEditingAnniversary() },
                            onCancelEdit: { vm.cancelEditingAnniversary() },
                            onSaveAnniv: { Task { await vm.saveAnniversary() } }
                        )

                        SectionHeader("Widget customization", systemImage: "photo.on.rectangle.angled")

                        WidgetPhotoPickerRow { image in
                            Task { await vm.setWidgetPhoto(image) }
                        }

                        if let img = SharedWidgetStore.loadWidgetPhoto() {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.08)))
                                .accessibilityLabel("Current widget photo")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 52)
                }
                .navigationTitle("Anniversary")
                .background(staticBackground)
            }
            .tabItem { Label("Anniversary", systemImage: "heart.circle.fill") }
            .tag(1)
            
            
            // TAB 3: QUIZ
            if let coupleId = vm.couple?.id,
               let myUid = Auth.auth().currentUser?.uid,
               let partnerUid = vm.couple?.memberUids.first(where: { $0 != myUid }) {
                QuizTabView(coupleId: coupleId, myUid: myUid, partnerUid: partnerUid)
                    .tabItem { Label("Quiz", systemImage: "questionmark.circle.fill") }
                    .tag(2)
            }


        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Views per state
    @ViewBuilder
    private func stateView() -> some View {
        switch vm.state {
        case .noCouple:
            NoCoupleSection(
                joinCode: $vm.joinCode,
                onCreate: { Task { await vm.generateAndCreateCouple() } },
                onJoin:   { Task { await vm.joinCoupleByCode() } }
            )

        case .createdWaiting(let code, let memberCount):
            CreatedWaitingSection(code: code, memberCount: memberCount)

        case .joinedPending(let code, let memberCount):
            JoinedPendingSection(code: code, memberCount: memberCount)

        case .matched(let code):
            MatchedSection(
                code: code,
                couple: vm.couple,
                isEditing: $vm.isEditingAnniversary,
                picked: $vm.pickedAnniversary,
                onEdit: { vm.startEditingAnniversary() },
                onCancelEdit: { vm.cancelEditingAnniversary() },
                onSaveAnniv: { Task { await vm.saveAnniversary() } },
                onRemoveConnection: { Task { await vm.leaveCouple() } },
                lastSent: vm.lastSent,
                onResend: {
                    if let text = vm.lastSent?.text {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        vm.sendLoveMessage(text)
                    }
                },
                onEditResend: { newText in
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    vm.sendLoveMessage(newText)
                },
                onClearLast: {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    vm.lastSent = nil 
                },
                onSendLove: { msg in
                    vm.sendLoveMessage(msg)
                }
            )
        }
    }

    // MARK: - Static background
    private var staticBackground: some View {
        LinearGradient(
            colors: UITheme.gradientColors,
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .opacity(0.14)
        .overlay(
            RadialGradient(
                colors: [UITheme.accent.opacity(0.14), .clear],
                center: .init(x: 0.85, y: 0.12),
                startRadius: 20, endRadius: 1200
            )
        )
        .ignoresSafeArea()
    }
}

// MARK: - Small, focused subviews

private struct HeaderCard: View {
    let displayName: String?
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(UITheme.accent.opacity(0.15))
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(UITheme.accent)
            }
            .frame(width: 46, height: 46)
            .shadow(color: UITheme.accent.opacity(0.2), radius: 10, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome, \(displayName ?? "there")").font(.headline)
                Text("Let’s connect your accounts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(UITheme.glassBG(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08))
        }
    }
}

private struct NoCoupleSection: View {
    @Binding var joinCode: String
    let onCreate: () -> Void
    let onJoin: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            SectionHeader("Match with your partner", systemImage: "sparkles")
            MatchCardEmpty(joinCode: $joinCode, onCreate: onCreate, onJoin: onJoin)
        }
    }
}

private struct CreatedWaitingSection: View {
    let code: String
    let memberCount: Int
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader("Invite your partner", systemImage: "paperplane.circle.fill")
            CreatedWaitingCard(code: code, members: memberCount)
        }
    }
}

private struct JoinedPendingSection: View {
    let code: String
    let memberCount: Int
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader("Pending", systemImage: "hourglass.circle.fill")
            JoinedPendingCard(code: code, members: memberCount)
        }
    }
}

private struct MatchedSection: View {
    let code: String
    let couple: Couple?
    @Binding var isEditing: Bool
    @Binding var picked: Date        // <- Date, nu Date?
    let onEdit: () -> Void
    let onCancelEdit: () -> Void
    let onSaveAnniv: () -> Void
    let onRemoveConnection: () -> Void

    // Last message
    let lastSent: LastSent?
    let onResend: () -> Void
    let onEditResend: (_ newText: String) -> Void
    let onClearLast: () -> Void

    // Love composer
    let onSendLove: (_ message: String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            SectionHeader("You’re matched!", systemImage: "link.circle.fill")
            CoupleCardMatched(
                code: code,
                couple: couple,
                isEditing: $isEditing,
                picked: $picked,
                onEdit: onEdit,
                onCancelEdit: onCancelEdit,
                onSaveAnniv: onSaveAnniv,
                onRemoveConnection: onRemoveConnection
            )

            if let last = lastSent {
                SectionHeader("Last message", systemImage: "clock.badge.checkmark")
                LastMessageSection(
                    msg: last,
                    onResend: onResend,
                    onEditResend: onEditResend,
                    onClear: onClearLast
                )
            }

            SectionHeader("Send love", systemImage: "paperplane.fill")
            LoveComposer { text in onSendLove(text) }
        }
    }
}

private struct LastMessageSection: View {
    let msg: LastSent
    let onResend: () -> Void
    let onEditResend: (_ newText: String) -> Void
    let onClear: () -> Void

    var body: some View {
        LastSentBar(
            msg: msg,
            onResend: onResend,
            onEditResend: onEditResend,
            onClear: onClear
        )
    }
}
