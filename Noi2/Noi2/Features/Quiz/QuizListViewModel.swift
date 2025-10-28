//
//  QuizListViewModel.swift
//  Noi2
//
//  Created by Cristi Sandu on 25.10.2025.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - QuizListViewModel

@MainActor
final class QuizListViewModel: ObservableObject {
    @Published var items: [QuizListItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    struct QuizListItem: Identifiable, Equatable {
        let id: String            // quizId
        let quiz: Quiz
        let myCompleted: Bool
        let partnerCompleted: Bool
        let matchPercent: Int?
        let partnerWaiting: Bool
    }

    let coupleId: String
    let myUid: String
    let partnerUid: String

    private var listenTasks: [Task<Void, Never>] = []
    private var quizzes: [Quiz] = []

    init(coupleId: String, myUid: String, partnerUid: String) {
        self.coupleId = coupleId
        self.myUid = myUid
        self.partnerUid = partnerUid
    }

    func onAppear() {
        if !items.isEmpty { return }
        Task { await load() }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            quizzes = try await QuizService.shared.fetchAllQuizzes()
            items = quizzes.map {
                .init(id: $0.id, quiz: $0, myCompleted: false, partnerCompleted: false, matchPercent: nil, partnerWaiting: false)
            }
            subscribeToAttempts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func subscribeToAttempts() {
        listenTasks.forEach { $0.cancel() }
        listenTasks.removeAll()

        for quiz in quizzes {
            let t = Task { [weak self] in
                guard let self else { return }
                for await (me, partner) in QuizService.shared.listenAttempts(
                    coupleId: coupleId, quizId: quiz.id, myUid: myUid, partnerUid: partnerUid
                ) {
                    guard let idx = self.items.firstIndex(where: { $0.id == quiz.id }) else { continue }
                    let summary = QuizPairSummary.compute(quiz: quiz, me: me, partner: partner)
                    self.items[idx] = .init(
                        id: quiz.id,
                        quiz: quiz,
                        myCompleted: me?.completedAt != nil,
                        partnerCompleted: partner?.completedAt != nil,
                        matchPercent: (me?.completedAt != nil && partner?.completedAt != nil) ? summary.matchPercent : nil,
                        partnerWaiting: (me?.completedAt != nil && partner?.completedAt == nil)
                    )
                }
            }
            listenTasks.append(t)
        }
    }
}


// MARK: - QuizRunViewModel

@MainActor
final class QuizRunViewModel: ObservableObject {
    @Published var quiz: Quiz
    @Published var currentIndex: Int = 0
    @Published var answers: [Int]
    @Published var partnerAnswers: [Int]? = nil

    @Published var partnerCompleted = false
    @Published var myCompleted = false

    @Published var matchPercent: Int = 0
    @Published var perQuestionMatch: [Bool] = []
    
    @Published var canReveal: Bool = false
    @Published var justFinished: Bool = false
    @Published var partnerJustFinished: Bool = false


    let coupleId: String
    let myUid: String
    let partnerUid: String
    let displayName: String?

    private var listenTask: Task<Void, Never>?

    init(quiz: Quiz, coupleId: String, myUid: String, partnerUid: String, displayName: String?) {
        self.quiz = quiz
        self.coupleId = coupleId
        self.myUid = myUid
        self.partnerUid = partnerUid
        self.displayName = displayName
        self.answers = Array(repeating: -1, count: quiz.questions.count)
    }

    func start() {
        listenTask?.cancel()
        listenTask = Task { [weak self] in
            guard let self else { return }

            for await (me, partner) in QuizService.shared.listenAttempts(
                coupleId: coupleId, quizId: quiz.id, myUid: myUid, partnerUid: partnerUid
            ) {
                let prevMyCompleted = self.myCompleted
                let prevPartnerCompleted = self.partnerCompleted

                if let me = me {
                    self.answers = me.answers
                    self.myCompleted = me.completedAt != nil
                }

                if let partner = partner {
                    self.partnerCompleted = partner.completedAt != nil
                }


                self.canReveal = self.myCompleted && self.partnerCompleted
                if self.canReveal {
                    self.partnerAnswers = partner?.answers
                } else {
                    self.partnerAnswers = nil
                }

                let summary = QuizPairSummary.compute(quiz: quiz, me: me, partner: partner)
                self.matchPercent = self.canReveal ? summary.matchPercent : 0
                self.perQuestionMatch = self.canReveal ? summary.perQuestionMatch : Array(repeating: false, count: quiz.questions.count)

                self.justFinished = (!prevMyCompleted && self.myCompleted)
                self.partnerJustFinished = (!prevPartnerCompleted && self.partnerCompleted)

                if self.justFinished {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else if self.partnerJustFinished && !self.myCompleted {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
    }



    func answer(_ optionIndex: Int) {
        guard currentIndex < answers.count else { return }
        answers[currentIndex] = optionIndex
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            try? await QuizService.shared.saveProgress(
                coupleId: coupleId,
                quiz: quiz,
                uid: myUid,
                displayName: displayName,
                answers: answers,
                completed: false
            )
        }
    }

    func next() {
        guard currentIndex < quiz.questions.count - 1 else { return }
        currentIndex += 1
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func prev() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func submit() {
        guard !answers.contains(-1) else { return }
        guard !myCompleted else { return }
        Task {
            try? await QuizService.shared.saveProgress(
                coupleId: coupleId,
                quiz: quiz,
                uid: myUid,
                displayName: displayName,
                answers: answers,
                completed: true
            )
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
