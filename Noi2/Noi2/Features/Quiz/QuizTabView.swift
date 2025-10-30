//
//  QuizTabView.swift
//  Noi2
//
//  Created by Cristi Sandu on 25.10.2025.
//

import SwiftUI
import FirebaseAuth

// MARK: - Root

struct QuizTabView: View {
    @StateObject private var vm: QuizListViewModel

    init(coupleId: String, myUid: String, partnerUid: String) {
        _vm = StateObject(wrappedValue: QuizListViewModel(
            coupleId: coupleId, myUid: myUid, partnerUid: partnerUid
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QuizMinimalBackground()
                ScrollView {
                    LazyVStack(spacing: 14) {
                       

                        ForEach(vm.items) { item in
                            NavigationLink {
                                QuizRunView(
                                    quiz: item.quiz,
                                    coupleId: vm.coupleId,
                                    myUid: vm.myUid,
                                    partnerUid: vm.partnerUid,
                                    displayName: Auth.auth().currentUser?.displayName
                                )
                            } label: {
                                QuizMinimalCard {
                                    QuizCardRow(item: item)
                                }
                                .padding(.horizontal, 16)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("Quizzes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .onAppear { vm.onAppear() }
        }
    }
}

// MARK: - Card list row

private struct QuizCardRow: View {
    let item: QuizListViewModel.QuizListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.quiz.title)
                        .font(.headline)
                    Text(item.quiz.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                MatchBadgeMinimal(matchPercent: item.matchPercent)
            }

            HStack(spacing: 8) {
                StatusPillMinimal(system: "person",
                                  text: item.myCompleted ? "You: done" : "You: in progress")
                StatusPillMinimal(system: "heart",
                                  text: item.partnerCompleted
                                  ? "Partner: done"
                                  : (item.partnerWaiting ? "Waiting partner" : "Partner: not started"))
                Spacer(minLength: 0)
            }
        }
    }
}

private struct MatchBadgeMinimal: View {
    let matchPercent: Int?
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.primary.opacity(0.06))
                .frame(width: 40, height: 40)
            Text(matchPercent.map { "\($0)%" } ?? "–")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityLabel(matchPercent != nil ? "Match \(matchPercent!) percent" : "No match yet")
    }
}

private struct StatusPillMinimal: View {
    let system: String
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: system)
            Text(text)
        }
        .font(.footnote.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Run screen

struct QuizRunView: View {
    @StateObject private var vm: QuizRunViewModel

    init(quiz: Quiz, coupleId: String, myUid: String, partnerUid: String, displayName: String?) {
        _vm = StateObject(wrappedValue: QuizRunViewModel(
            quiz: quiz,
            coupleId: coupleId,
            myUid: myUid,
            partnerUid: partnerUid,
            displayName: displayName
        ))
    }

    var body: some View {
        ZStack {
            QuizMinimalBackground()
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                QuizProgressBar(current: vm.currentIndex + 1, total: vm.quiz.questions.count)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                content
                    .padding(.bottom, 8)

                footer
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .navigationTitle(vm.quiz.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.start() }
        .safeAreaInset(edge: .bottom) { comparisonFooter }
    }

    private var header: some View {
        HStack {
            Text(vm.quiz.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            if vm.canReveal {
                StatusPillMinimal(system: "lock.open.fill", text: "Results unlocked")
            } else if vm.partnerCompleted {
                StatusPillMinimal(system: "heart.fill", text: "Partner finished")
            } else {
                StatusPillMinimal(system: "heart", text: "Partner live")
            }
        }
    }

    private var content: some View {
        let q = vm.quiz.questions[vm.currentIndex]
        return VStack(alignment: .leading, spacing: 14) {
            QuizMinimalCard {
                Text(q.text)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(q.options.indices, id: \.self) { idx in
                QuizMinimalCard {
                    OptionRowMinimal(
                        index: idx,
                        text: q.options[idx],
                        selected: vm.answers[vm.currentIndex] == idx,
                        partnerSelected: vm.canReveal ? (vm.partnerAnswers?[vm.currentIndex] == idx) : false
                    )
                }
                .onTapGesture { vm.answer(idx) }
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: vm.prev) {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(vm.currentIndex == 0)

            Spacer()

            if vm.currentIndex < vm.quiz.questions.count - 1 {
                Button(action: vm.next) {
                    Label("Next", systemImage: "chevron.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.answers[vm.currentIndex] == -1)
            } else {
                Button(action: vm.submit) {
                    Label(vm.myCompleted ? "Submitted" : "Submit",
                          systemImage: vm.myCompleted ? "checkmark.circle" : "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.answers.contains(-1) || vm.myCompleted)
            }
        }
    }

    private var comparisonFooter: some View {
        VStack(spacing: 10) {
            NavigationLink {
                QuizResultView(
                    quiz: vm.quiz,
                    myAnswers: vm.answers,
                    partnerAnswers: vm.partnerAnswers ?? Array(repeating: -1, count: vm.quiz.questions.count),
                    matchPercent: vm.matchPercent,
                    perQuestionMatch: vm.perQuestionMatch
                )
            } label: {
                QuizMinimalCard {
                    HStack(spacing: 10) {
                        Image(systemName: vm.canReveal ? "chart.bar.fill" : "lock.fill")
                        Text(vm.canReveal ? "See results & compare" : "Finish both to unlock")
                        Spacer()
                        Text(vm.canReveal ? "\(vm.matchPercent)%" : "Locked")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .disabled(!vm.canReveal)
        }
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
}

// MARK: - Progress bar (minimal)

private struct QuizProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Question \(current) / \(max(1, total))")
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let w = geo.size.width
                let p = CGFloat(current) / CGFloat(max(1, total))
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.3))
                            .frame(width: w * p)
                    }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Minimal option row

private struct OptionRowMinimal: View {
    let index: Int
    let text: String
    let selected: Bool
    let partnerSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(Color.primary.opacity(selected ? 0 : 0.20), lineWidth: 1)
                    .background(Circle().fill(selected ? Color.primary.opacity(0.12) : .clear))
                    .frame(width: 24, height: 24)
                if selected { Image(systemName: "checkmark").font(.footnote.weight(.bold)) }
            }
            Text(text).font(.body)
            Spacer()

            if partnerSelected {
                Image(systemName: "heart.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.pink)
                    .accessibilityLabel("Partner chose this")
            }
        }
    }
}

// MARK: - Results

struct QuizResultView: View {
    let quiz: Quiz
    let myAnswers: [Int]
    let partnerAnswers: [Int]
    let matchPercent: Int
    let perQuestionMatch: [Bool]

    var body: some View {
        ZStack {
            QuizMinimalBackground()
            ScrollView {
                VStack(spacing: 16) {
                    QuizMinimalCard {
                        VStack(spacing: 6) {
                            Text("Your match is")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(matchPercent)%")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(quiz.questions.indices, id: \.self) { i in
                            QuizMinimalCard {
                                ResultRowMinimal(
                                    index: i + 1,
                                    question: quiz.questions[i].text,
                                    my: myAnswers[safe: i].flatMap { quiz.questions[i].options[safe: $0] } ?? "–",
                                    partner: partnerAnswers[safe: i].flatMap { quiz.questions[i].options[safe: $0] } ?? "–",
                                    matched: perQuestionMatch[safe: i] ?? false
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    if perQuestionMatch.allSatisfy({ $0 }) {
                        ConfettiViewMinimal()
                            .frame(height: 140)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ResultRowMinimal: View {
    let index: Int
    let question: String
    let my: String
    let partner: String
    let matched: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Q\(index)")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                Text(question)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(3)
                Spacer()
                Image(systemName: matched ? "heart.fill" : "heart")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(matched ? .pink : .secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Label(my, systemImage: "person")
                    .font(.callout)
                Label(partner, systemImage: "heart")
                    .font(.callout)
            }
            .padding(10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Minimal confetti (very subtle)

private struct ConfettiViewMinimal: View {
    @State private var bounce = false
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Canvas { ctx, _ in
                for i in 0..<28 {
                    let x = CGFloat(i) / 28.0 * w
                    let y = (bounce ? 0.78 : 0.22) * h + CGFloat((i % 5) * 2)
                    let rect = Path(ellipseIn: CGRect(x: x, y: y, width: 5, height: 5))
                    ctx.fill(rect, with: .color(.primary.opacity(0.22)))
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    bounce.toggle()
                }
            }
        }
    }
}


private struct QuizMinimalBackground: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            LinearGradient(
                colors: [Color.black.opacity(0.02), .clear],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct QuizMinimalCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBG, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(border, lineWidth: 0.5)
            )
    }

    private var cardBG: AnyShapeStyle {
        if UIAccessibility.isReduceTransparencyEnabled {
            return AnyShapeStyle(Color(.secondarySystemBackground))
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    private var border: Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }
}

private struct QuizMinimalHeader: View {
    @Environment(\.colorScheme) private var scheme
    var title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer(minLength: 0)
        }
        .overlay(
            Rectangle()
                .fill(scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
                .frame(height: 0.5)
                .offset(y: 17),
            alignment: .bottom
        )
        .accessibilityAddTraits(.isHeader)
    }
}

