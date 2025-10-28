//
//  QuizService.swift
//  Noi2
//
//  Created by Cristi Sandu on 25.10.2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore


@MainActor
final class QuizService: ObservableObject {
    static let shared = QuizService()
    private init() {}

    private let db = Firestore.firestore()

    // MARK: - Paths
    struct Paths {
        let db: Firestore
        func publicQuiz(_ quizId: String) -> DocumentReference {
            db.collection("public_quizzes").document(quizId)
        }
        func publicQuizQuestions(_ quizId: String) -> CollectionReference {
            publicQuiz(quizId).collection("questions")
        }
        func attempts(coupleId: String, quizId: String) -> CollectionReference {
            db.collection("couples").document(coupleId)
                .collection("quizzes").document(quizId)
                .collection("attempts")
        }
        func attemptDoc(coupleId: String, quizId: String, uid: String) -> DocumentReference {
            attempts(coupleId: coupleId, quizId: quizId).document(uid)
        }
    }
    private var paths: Paths { Paths(db: db) }

    // MARK: - Public Quizzes

    func fetchAllQuizMeta() async throws -> [QuizMeta] {
        let snap = try await db.collection("public_quizzes")
            .order(by: "title")
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: QuizMeta.self) }
    }

    func fetchQuiz(quizId: String) async throws -> Quiz {
        let metaRef = paths.publicQuiz(quizId)
        let meta = try await metaRef.getDocument().data(as: QuizMeta.self)

        let qSnap = try await paths.publicQuizQuestions(quizId)
            .order(by: "order")
            .getDocuments()

        let questions: [Quiz.QuizQuestionLite] = qSnap.documents.compactMap { doc in
            guard let q = try? doc.data(as: QuizQuestion.self) else { return nil }
            return .init(id: q.questionId, text: q.text, options: q.options)
        }

        return .init(id: meta.quizId, title: meta.title, subtitle: meta.subtitle, questions: questions)
    }

    func fetchAllQuizzes() async throws -> [Quiz] {
        let metas = try await fetchAllQuizMeta()
        var result: [Quiz] = []
        result.reserveCapacity(metas.count)
        for meta in metas {
            let q = try await fetchQuiz(quizId: meta.quizId)
            result.append(q)
        }
        return result
    }

    // MARK: - Attempts (listen + save)

    func listenAttempts(coupleId: String, quizId: String, myUid: String, partnerUid: String)
    -> AsyncStream<(QuizAttempt?, QuizAttempt?)> {
        let myRef = paths.attemptDoc(coupleId: coupleId, quizId: quizId, uid: myUid)
        let partnerRef = paths.attemptDoc(coupleId: coupleId, quizId: quizId, uid: partnerUid)

        return AsyncStream { continuation in
            var myListener: ListenerRegistration?
            var partnerListener: ListenerRegistration?
            var myCache: QuizAttempt?
            var partnerCache: QuizAttempt?

            func emit() { continuation.yield((myCache, partnerCache)) }

            myListener = myRef.addSnapshotListener { snap, _ in
                myCache = try? snap?.data(as: QuizAttempt.self)
                emit()
            }
            partnerListener = partnerRef.addSnapshotListener { snap, _ in
                partnerCache = try? snap?.data(as: QuizAttempt.self)
                emit()
            }

            continuation.onTermination = { _ in
                myListener?.remove()
                partnerListener?.remove()
            }
        }
    }

    func saveProgress(
        coupleId: String,
        quiz: Quiz,
        uid: String,
        displayName: String?,
        answers: [Int],
        completed: Bool
    ) async throws {
        let now = Timestamp(date: Date())
        var attempt = QuizAttempt(
            id: uid,
            uid: uid,
            displayName: displayName,
            answers: answers,
            startedAt: now,
            completedAt: completed ? now : nil
        )
        try paths.attemptDoc(coupleId: coupleId, quizId: quiz.id, uid: uid)
            .setData(from: attempt, merge: true)
    }
}
