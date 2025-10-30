//
//  AppDelegate.swift
//  Noi2
//
//  Created by Cristi Sandu on 19.10.2025.
//

import UIKit
import UserNotifications
import FirebaseCore
import GoogleSignIn
import WidgetKit
import CloudKit
import OSLog

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private let log = Logger(subsystem: "ro.csx.Noi2x", category: "AppDelegate")

    // MARK: - App lifecycle
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        // Firebase bootstrap (Auth/Firestore used elsewhere)
        FirebaseApp.configure()

        // Google Sign-In setup (keeps config in one place)
        if let cid = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: cid)
        }

        // Notifications: delegate + categories + request permission
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, err in
            if let err { self?.log.error("[NOTIF] requestAuthorization error: \(err.localizedDescription, privacy: .public)") }
            self?.log.info("[NOTIF] permission granted = \(granted, privacy: .public)")
            if granted {
                DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
            }
        }

        // (Optional) Debug-only: iCloud account status
        #if DEBUG
        Task { [weak self] in
            do {
                let status = try await CKContainer.default().accountStatus()
                self?.log.info("[CK] accountStatus = \(status.rawValue, privacy: .public)") // 1 = available
            } catch {
                self?.log.error("[CK] accountStatus error: \(error.localizedDescription, privacy: .public)")
            }
        }
        #endif

        return true
    }

    // MARK: - URL handling (Google Sign-In)
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - APNs registration
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if DEBUG
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        log.debug("[APNs] deviceToken (debug) = \(hex, privacy: .private)")
        #endif
        // FCM: Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        log.error("[APNs] didFailToRegister error = \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Foreground notification presentation
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        let userInfo = notification.request.content.userInfo

        // Silent CloudKit notification → no banner, just trigger sync
        if isCloudKitSilent(userInfo: userInfo) {
            completionHandler([])
            postCKSignal(from: userInfo)
            return
        }

        // Alert CloudKit notification → show banner, sound, badge
        completionHandler([.banner, .list, .sound, .badge])
    }

    // MARK: - Background notification handling
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        if isCloudKitNotification(userInfo: userInfo) {
            postCKSignal(from: userInfo)
            completionHandler(.newData)
            return
        }

        completionHandler(.noData)
    }

    // MARK: - User responses to notifications (tap / reply)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "REPLY":
            if let textResponse = response as? UNTextInputNotificationResponse {
                let reply = textResponse.userText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !reply.isEmpty {
                    NotificationCenter.default.post(
                        name: .init("LoveMessageQuickReply"),
                        object: nil,
                        userInfo: ["text": reply]
                    )
                }
            }

        default:
            // Tap on banner → trigger data refresh
            if isCloudKitNotification(userInfo: userInfo) {
                postCKSignal(from: userInfo)
            }
        }

        completionHandler()
    }
}

// MARK: - Helpers
private extension AppDelegate {

    /// Notification categories (Reply / Open)
    func registerNotificationCategories() {
        let reply = UNTextInputNotificationAction(
            identifier: "REPLY",
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type a message…"
        )
        let open = UNNotificationAction(
            identifier: "OPEN",
            title: "Open",
            options: [.foreground]
        )
        let loveCategory = UNNotificationCategory(
            identifier: "LOVE_MESSAGE",
            actions: [reply, open],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([loveCategory])
    }

    // MARK: - CloudKit helpers

    func isCloudKitNotification(userInfo: [AnyHashable: Any]) -> Bool {
        CKNotification(fromRemoteNotificationDictionary: userInfo) != nil
    }

    func isCloudKitSilent(userInfo: [AnyHashable: Any]) -> Bool {
        guard isCloudKitNotification(userInfo: userInfo),
              let aps = userInfo["aps"] as? [String: Any] else { return false }
        let hasContentAvailable = (aps["content-available"] as? Int) == 1
        let hasAlert = aps["alert"] != nil
        return hasContentAvailable && !hasAlert
    }

    /// Sends an internal signal for ViewModels to refetch Firestore data + refresh widgets.
    func postCKSignal(from userInfo: [AnyHashable: Any]) {
        let ck = CKNotification(fromRemoteNotificationDictionary: userInfo)

        NotificationCenter.default.post(name: .init("CKSilentSignal"), object: ck)

        // Proactive: refresh widgets when anything CloudKit-related hits
        WidgetCenter.shared.reloadAllTimelines()

        #if DEBUG
        if let qn = ck as? CKQueryNotification {
            log.debug("[CK] QueryNotification reason=\(qn.queryNotificationReason.rawValue, privacy: .public) recordID=\(qn.recordID?.recordName ?? "nil", privacy: .public)")
        } else {
            log.debug("[CK] Notification received (type=\(ck?.notificationType.rawValue ?? -1, privacy: .public))")
        }
        #endif
    }
}
