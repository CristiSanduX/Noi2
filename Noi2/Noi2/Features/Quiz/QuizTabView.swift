//
//  QuizTabView.swift
//  Noi2
//
//  Created by Cristi Sandu on 25.10.2025.
//

import SwiftUI
import FirebaseAuth

// MARK: - Tab principal
struct QuizTabView: View {
    @StateObject private var vm: QuizListViewModel

    init(coupleId: String, myUid: String, partnerUid: String) {
        _vm = StateObject(wrappedValue: QuizListViewModel(coupleId: coupleId, myUid: myUid, partnerUid: partnerUid))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
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
                            QuizCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Quizzes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "sparkles")
                }
            }
            .onAppear { vm.onAppear() }
        }
    }
}

// MARK: - Card de quiz
struct QuizCard: View {
    let item: QuizListViewModel.QuizListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.quiz.title)
                        .font(.title3.weight(.semibold))
                    Text(item.quiz.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                MatchBadge(matchPercent: item.matchPercent)
            }

            HStack(spacing: 10) {
                StatusPill(system: "person", text: item.myCompleted ? "You: done" : "You: in progress")
                StatusPill(system: "heart", text: item.partnerCompleted ? "Partner: done" : (item.partnerWaiting ? "Waiting partner" : "Partner: not started"))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(radius: 4, y: 2)
    }
}

struct MatchBadge: View {
    let matchPercent: Int?
    var body: some View {
        ZStack {
            Circle().fill(Color.primary.opacity(0.06)).frame(width: 46, height: 46)
            Text(matchPercent.map { "\($0)%" } ?? "–")
                .font(.callout.weight(.semibold))
        }
    }
}

struct StatusPill: View {
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
    }
}

// MARK: - Ecranul de quiz
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
        VStack(spacing: 0) {
            header
            progressBar
            content
            footer
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
            Spacer()
            if vm.canReveal {
                StatusPill(system: "lock.open.fill", text: "Results unlocked")
            } else if vm.partnerCompleted {
                StatusPill(system: "heart.fill", text: "Partner finished")
            } else {
                StatusPill(system: "heart", text: "Partner live")
            }

        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var progressBar: some View {
        VStack(alignment: .leading) {
            Text("Question \(vm.currentIndex + 1) / \(vm.quiz.questions.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                let w = geo.size.width
                let progress = CGFloat(vm.currentIndex + 1) / CGFloat(max(1, vm.quiz.questions.count))
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.3))
                            .frame(width: w * progress)
                    }
            }.frame(height: 6)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var content: some View {
        let q = vm.quiz.questions[vm.currentIndex]
        return VStack(alignment: .leading, spacing: 16) {
            Text(q.text)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            VStack(spacing: 10) {
                ForEach(q.options.indices, id: \.self) { idx in
                    OptionRow(
                        index: idx,
                        text: q.options[idx],
                        selected: vm.answers[vm.currentIndex] == idx,
                        partnerSelected: vm.canReveal ? (vm.partnerAnswers?[vm.currentIndex] == idx) : false

                    )
                    .onTapGesture { vm.answer(idx) }
                    .padding(.horizontal)
                }
            }
            Spacer(minLength: 12)
        }
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
                    Label(vm.myCompleted ? "Submitted" : "Submit", systemImage: vm.myCompleted ? "checkmark.circle" : "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.answers.contains(-1) || vm.myCompleted)
            }
        }
        .padding()
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
                HStack {
                    Image(systemName: vm.canReveal ? "chart.bar.fill" : "lock.fill")
                    Text(vm.canReveal ? "See results & compare" : "Finish both to unlock")
                    Spacer()
                    Text(vm.canReveal ? "\(vm.matchPercent)%" : "Locked")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!vm.canReveal)

        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
}

// MARK: - Opțiuni
struct OptionRow: View {
    let index: Int
    let text: String
    let selected: Bool
    let partnerSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: selected ? 0 : 1)
                    .background(Circle().fill(selected ? Color.primary.opacity(0.15) : Color.clear))
                    .frame(width: 24, height: 24)
                if selected { Image(systemName: "checkmark") }
            }
            Text(text).font(.body)
            Spacer()

            if partnerSelected {
                Image(systemName: "heart.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.pink)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
}


// MARK: - Rezultate
struct QuizResultView: View {
    let quiz: Quiz
    let myAnswers: [Int]
    let partnerAnswers: [Int]
    let matchPercent: Int
    let perQuestionMatch: [Bool]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("Your match is")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(matchPercent)%")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(quiz.questions.indices, id: \.self) { i in
                        ResultRow(
                            index: i + 1,
                            question: quiz.questions[i].text,
                            my: myAnswers[safe: i].flatMap { quiz.questions[i].options[safe: $0] } ?? "–",
                            partner: partnerAnswers[safe: i].flatMap { quiz.questions[i].options[safe: $0] } ?? "–",
                            matched: perQuestionMatch[safe: i] ?? false
                        )
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)

                if perQuestionMatch.allSatisfy({ $0 }) {
                    ConfettiView()
                        .frame(height: 160)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ResultRow: View {
    let index: Int
    let question: String
    let my: String
    let partner: String
    let matched: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Q\(index)")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                Text(question)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: matched ? "heart.fill" : "heart")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(matched ? .pink : .secondary)
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(my, systemImage: "person")
                        .font(.callout)
                    Label(partner, systemImage: "heart")
                        .font(.callout)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ConfettiView: View {
    @State private var bounce = false
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Canvas { ctx, _ in
                for i in 0..<30 {
                    let x = CGFloat(i) / 30.0 * w
                    let y = (bounce ? 0.8 : 0.2) * h + CGFloat((i % 5) * 3)
                    let rect = Path(ellipseIn: CGRect(x: x, y: y, width: 6, height: 6))
                    ctx.fill(rect, with: .color(.primary.opacity(0.25)))
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
