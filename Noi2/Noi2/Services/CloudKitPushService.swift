//
//  CloudKitPushService.swift
//  Noi2
//
//  Created by Cristi Sandu on 23.10.2025.
//

import CloudKit
import UIKit

enum CKPushError: Error { case noICloudAccount, notFound }

final class CloudKitPushService {
    static let shared = CloudKitPushService()
    private init() {}

    // Uses the default container from entitlements.
    private let container = CKContainer.default()
    private var db: CKDatabase { container.publicCloudDatabase }

    // MARK: - Record bootstrap / fetch

    /// Ensures a `CoupleSignal` record exists for the given coupleId.
    /// If missing, it creates one (which also bootstraps the schema in Development).
    @discardableResult
    func ensureSignalRecord(for coupleId: String) async throws -> CKRecord {
        let predicate = NSPredicate(format: "coupleId == %@", coupleId)
        let query = CKQuery(recordType: "CoupleSignal", predicate: predicate)

        do {
            let (results, _) = try await db.records(matching: query)
            if let record = results.compactMap({ try? $0.1.get() }).first {
                return record
            }
        } catch let ck as CKError where ck.code == .unknownItem {
            // Record type might not exist yet in Development → proceed to create.
        } catch {
            // Any other error while querying → rethrow
            throw error
        }

        // Create a fresh record when none was found
        let rec = CKRecord(recordType: "CoupleSignal")
        rec["coupleId"] = coupleId as CKRecordValue
        rec["lastEventAt"] = Date() as CKRecordValue
        rec["eventType"] = "bootstrap" as CKRecordValue
        return try await save(rec)
    }

    // MARK: - Push trigger

    /// Touches the `CoupleSignal` record so CloudKit fires the subscription.
    func bump(coupleId: String, eventType: String, version: Int? = nil) async {
        do {
            var rec = try await ensureSignalRecord(for: coupleId)
            rec["lastEventAt"] = Date() as CKRecordValue
            rec["eventType"] = eventType as CKRecordValue
            if let version { rec["version"] = version as CKRecordValue }
            _ = try await save(rec)
            print("[CK] bump ok for coupleId=\(coupleId) event=\(eventType)")
        } catch {
            print("[CK] bump failed:", error)
        }
    }

    // MARK: - Subscriptions (visible alert)

    /// Ensures a CKQuerySubscription exists for this coupleId with a visible alert payload.
    func ensureSubscription(for coupleId: String) async {
        let subID = "signal-\(coupleId)"

        // If it already exists, keep it as-is.
        do {
            _ = try await fetchSubscription(id: subID)
            print("[CK] Subscription already exists:", subID)
            return
        } catch {
            // Fall through to create a fresh one.
        }

        let predicate = NSPredicate(format: "coupleId == %@", coupleId)
        let sub = CKQuerySubscription(
            recordType: "CoupleSignal",
            predicate: predicate,
            subscriptionID: subID,
            options: [.firesOnRecordUpdate, .firesOnRecordCreation]
        )

        // Configure visible banner (not silent).
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = false
        info.title = "Noi2"
        info.alertBody = "New message from your partner 💌"
        info.soundName = "default"
        info.shouldBadge = true
        info.category = "LOVE_MESSAGE" // must match UNNotificationCategory in AppDelegate
        sub.notificationInfo = info

        do {
            _ = try await save(subscription: sub)
            print("[CK] Created subscription:", subID)
        } catch {
            print("[CK] Save subscription failed:", error)
        }
    }

    /// Deletes (if present) and recreates the subscription with the current NotificationInfo.
    func recreateSubscription(for coupleId: String) async {
        let subID = "signal-\(coupleId)"
        _ = try? await deleteSubscription(id: subID)
        await ensureSubscription(for: coupleId)
    }

    /// Optional helper to tidy up after leaving a couple.
    func deleteSubscription(for coupleId: String) async {
        let subID = "signal-\(coupleId)"
        _ = try? await deleteSubscription(id: subID)
        print("[CK] Deleted subscription (if existed):", subID)
    }

    // MARK: - Utilities

    /// Returns the recordID after ensuring the record exists.
    func recordID(for coupleId: String) async -> CKRecord.ID? {
        do {
            let rec = try await ensureSignalRecord(for: coupleId)
            return rec.recordID
        } catch {
            print("[CK] resolve recordID failed:", error)
            return nil
        }
    }

    // MARK: - Low-level async wrappers

    private func save(_ record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { cont in
            db.save(record) { rec, err in
                if let err { cont.resume(throwing: err) }
                else if let rec { cont.resume(returning: rec) }
                else { cont.resume(throwing: NSError(domain: "Noi2", code: -3)) }
            }
        }
    }

    private func fetchSubscription(id: String) async throws -> CKSubscription {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CKSubscription, Error>) in
            db.fetch(withSubscriptionID: id) { sub, err in
                if let sub { cont.resume(returning: sub) }
                else { cont.resume(throwing: err ?? NSError(domain: "Noi2", code: -1)) }
            }
        }
    }

    private func save(subscription: CKSubscription) async throws -> CKSubscription {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CKSubscription, Error>) in
            db.save(subscription) { saved, err in
                if let saved { cont.resume(returning: saved) }
                else { cont.resume(throwing: err ?? NSError(domain: "Noi2", code: -2)) }
            }
        }
    }

    private func deleteSubscription(id: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.delete(withSubscriptionID: id) { _, err in
                if let err { cont.resume(throwing: err) }
                else { cont.resume(returning: ()) }
            }
        }
    }
}
