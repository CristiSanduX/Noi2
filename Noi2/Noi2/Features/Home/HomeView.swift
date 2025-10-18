//
//  HomeView.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import SwiftUI
import PhotosUI
import UIKit

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
                    .padding(.bottom, 40)
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
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            // TAB 2: ANNIVERSARY
            NavigationStack {
                ScrollView {
                    AnniversaryTab(
                        couple: vm.couple,
                        isEditing: $vm.isEditingAnniversary,
                        picked: $vm.pickedAnniversary,
                        onEdit: { vm.startEditingAnniversary() },
                        onCancelEdit: { vm.cancelEditingAnniversary() },
                        onSaveAnniv: { Task { await vm.saveAnniversary() } }
                    )
                    .padding(20)
                    // spațiu ca să nu se lovească de Tab Bar
                    .padding(.bottom, 40)
                }
                .navigationTitle("Anniversary")
            }
            .tabItem {
                Label("Anniversary", systemImage: "heart.circle.fill")
            }
            .tag(1)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
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

// MARK: - Anniversary Tab

private struct AnniversaryTab: View {
    let couple: Couple?
    @Binding var isEditing: Bool
    @Binding var picked: Date
    var onEdit: () -> Void
    var onCancelEdit: () -> Void
    var onSaveAnniv: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            CouplePhotoCard()

            if let date = couple?.anniversary {
                AnniversaryHeroCard(anniversary: date)
                StatsGrid(anniversary: date)
                NextMilestoneCard(anniversary: date)

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
                                    .tint(Color("AccentColor"))
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
                VStack(spacing: 16) {
                    Label("Set your anniversary", systemImage: "sparkles")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color("AccentColor"))

                    DatePicker("Date", selection: $picked, displayedComponents: .date)
                        .datePickerStyle(.graphical)

                    Button("Save anniversary") { onSaveAnniv() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("AccentColor"))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Fancy Cards & Components

private struct AnniversaryHeroCard: View {
    let anniversary: Date

    var body: some View {
        let days = Calendar.current.dateComponents([.day], from: anniversary, to: Date()).day ?? 0
        ZStack {
            LinearGradient(
                colors: [
                    Color("AccentColor"),
                    Color("AccentColor").opacity(0.7)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .opacity(0.85)

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
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(radius: 8, y: 6)
    }

    private func progressToNextMilestone(fromDays days: Int) -> Double {
        let milestones = [100, 200, 300, 365, 500, 700, 1000, 1500, 2000]
        let next = milestones.first(where: { $0 > days }) ?? ( ((days/500)+1) * 500 )
        let prev = milestones.reversed().first(where: { $0 <= days }) ?? 0
        let span = max(1, next - prev)
        let p = Double(days - prev) / Double(span)
        return min(max(p, 0), 1)
    }
}

private struct StatsGrid: View {
    let anniversary: Date

    var body: some View {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: anniversary, to: Date())
        let years = comps.year ?? 0
        let months = comps.month ?? 0
        let daysTotal = Calendar.current.dateComponents([.day], from: anniversary, to: Date()).day ?? 0
        let weeks = daysTotal / 7

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatPill(title: "Years", value: "\(years)")
                StatPill(title: "Months", value: "\(months)")
            }
            HStack(spacing: 12) {
                StatPill(title: "Weeks", value: "\(weeks)")
                StatPill(title: "Days", value: "\(daysTotal)")
            }
        }
    }
}

private struct NextMilestoneCard: View {
    let anniversary: Date

    var body: some View {
        let days = Calendar.current.dateComponents([.day], from: anniversary, to: Date()).day ?? 0
        let (label, remaining) = nextMilestone(fromDays: days)

        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "flag.checkered")
                .font(.title3.weight(.semibold))
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Next milestone")
                    .font(.subheadline.weight(.semibold))
                Text(label)
                    .font(.headline)
                    .foregroundStyle(Color("AccentColor"))
                Text("\(remaining) days to go")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func nextMilestone(fromDays days: Int) -> (String, Int) {
        let milestones = [100, 200, 300, 365, 500, 700, 1000, 1500, 2000]
        let next = milestones.first(where: { $0 > days }) ?? ( ((days/500)+1) * 500 )
        let label = next == 365 ? "1 year" : "\(next) days"
        return (label, max(0, next - days))
    }
}

private struct StatPill: View {
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
    }
}

private struct RingView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.2), lineWidth: 10)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.white, .white.opacity(0.6), .white]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
    }
}

// MARK: - Couple Photo Card

struct CouplePhotoCard: View {
    @AppStorage("noi2_couple_photo") private var photoData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var uiImage: UIImage?
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color("AccentColor").opacity(0.18), .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .overlay(.ultraThinMaterial)
                    .shadow(radius: 8, y: 6)

                Group {
                    if let uiImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 42, weight: .bold))
                                .symbolEffect(.bounce, value: pulse)
                                .onAppear { pulse.toggle() }
                            Text("Add your photo")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                }

                // Badge „You & Partner”
                VStack {
                    HStack {
                        Label("You & Partner", systemImage: "heart.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .padding(12)
                        Spacer()
                    }
                    Spacer()
                }
            }

            HStack {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Label(uiImage == nil ? "Choose photo" : "Change photo", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(.bordered)
                .tint(Color("AccentColor"))

                if uiImage != nil {
                    Button(role: .destructive) {
                        withAnimation(.spring) {
                            uiImage = nil
                            photoData = nil
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let resized = image.resized(maxLength: 1200)
                    let out = resized.jpegData(compressionQuality: 0.85)
                    await MainActor.run {
                        self.uiImage = resized
                        self.photoData = out
                    }
                }
            }
        }
        .task {
            if let data = photoData, let img = UIImage(data: data) {
                uiImage = img
            }
        }
    }
}

// Helper for JPEG resize
fileprivate extension UIImage {
    func resized(maxLength: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        let scale = min(1, maxLength / max(w, h))
        guard scale < 1 else { return self }
        let newSize = CGSize(width: floor(w * scale), height: floor(h * scale))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Cards from previous Home (unchanged)

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

// MARK: - Love Composer

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
                .padding(10)
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
                    .foregroundStyle(Color("AccentColor"))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
