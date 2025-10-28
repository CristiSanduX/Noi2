//
//  QuizModels.swift
//  Noi2
//
//  Created by Cristi Sandu on 24.10.2025.
//


import Foundation
import FirebaseFirestore

// MARK: - Public quiz (metadata)
struct QuizMeta: Identifiable, Codable, Equatable {
    @DocumentID var id: String?   // quizId
    var title: String
    var subtitle: String

    var quizId: String { id ?? UUID().uuidString }
}

// MARK: - Public quiz question (în subcolecția questions)
struct QuizQuestion: Identifiable, Codable, Equatable {
    @DocumentID var id: String?   // questionId
    var text: String
    var options: [String]
    var order: Int

    var questionId: String { id ?? UUID().uuidString }
}

// MARK: - Quiz agregat în app (meta + întrebări)
struct Quiz: Identifiable, Equatable {
    var id: String                 // quizId
    var title: String
    var subtitle: String
    var questions: [QuizQuestionLite]

    struct QuizQuestionLite: Identifiable, Equatable {
        var id: String             // questionId
        var text: String
        var options: [String]
    }
}

// MARK: - Attempt (per user)
struct QuizAttempt: Identifiable, Codable {
    @DocumentID var id: String?
    var uid: String
    var displayName: String?
    var answers: [Int]                
    var startedAt: Timestamp
    var completedAt: Timestamp?
}

// MARK: - Pair summary (comparare)
struct QuizPairSummary {
    let myAttempt: QuizAttempt?
    let partnerAttempt: QuizAttempt?
    let matchPercent: Int
    let perQuestionMatch: [Bool]

    static func compute(quiz: Quiz, me: QuizAttempt?, partner: QuizAttempt?) -> QuizPairSummary {
        let qCount = quiz.questions.count
        let myAns = me?.answers ?? Array(repeating: -1, count: qCount)
        let partnerAns = partner?.answers ?? Array(repeating: -1, count: qCount)
        var matches = [Bool]()
        matches.reserveCapacity(qCount)
        for i in 0..<qCount {
            let ok = i < myAns.count && i < partnerAns.count && myAns[i] != -1 && myAns[i] == partnerAns[i]
            matches.append(ok)
        }
        let total = max(1, matches.count)
        let pct = Int((Double(matches.filter { $0 }.count) / Double(total)) * 100.0)
        return .init(myAttempt: me, partnerAttempt: partner, matchPercent: pct, perQuestionMatch: matches)
    }
}

// MARK: - Helpers

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
