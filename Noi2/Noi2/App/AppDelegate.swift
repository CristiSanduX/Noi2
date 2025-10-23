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

final class AppDelegate: NSObject,
                         UIApplicationDelegate,
                         UNUserNotificationCenterDelegate {

    // MARK: - App lifecycle
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        // Firebase (Auth, Firestore, etc.)
        FirebaseApp.configure()

        // Google Sign-In setup
        if let cid = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: cid)
        }

        // Notifications: delegate + permissions + APNs registration
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, err in
            print("[NOTIF] permission granted =", granted, "error =", String(describing: err))
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }

        // Debug: iCloud account status
        Task {
            do {
                let status = try await CKContainer.default().accountStatus()
                print("[CK] accountStatus =", status.rawValue) // 1 = available
            } catch {
                print("[CK] accountStatus error:", error)
            }
        }

        return true
    }

    // MARK: - URL handling (Google Sign-In)
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - APNs registration
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[APNs] deviceToken =", hex)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[APNs] didFailToRegister error =", error)
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
            // Notify listeners to refetch data (both for silent and alert)
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
                    // Post quick reply message event
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

    // MARK: - Helpers

    /// Notification categories (Reply / Open)
    private func registerNotificationCategories() {
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

    private func isCloudKitNotification(userInfo: [AnyHashable: Any]) -> Bool {
        CKNotification(fromRemoteNotificationDictionary: userInfo) != nil
    }

    private func isCloudKitSilent(userInfo: [AnyHashable: Any]) -> Bool {
        guard isCloudKitNotification(userInfo: userInfo),
              let aps = userInfo["aps"] as? [String: Any] else { return false }
        let hasContentAvailable = (aps["content-available"] as? Int) == 1
        let hasAlert = aps["alert"] != nil
        return hasContentAvailable && !hasAlert
    }

    /// Sends an internal signal for ViewModels to refetch Firestore data.
    private func postCKSignal(from userInfo: [AnyHashable: Any]) {
        let ck = CKNotification(fromRemoteNotificationDictionary: userInfo)
        NotificationCenter.default.post(name: .init("CKSilentSignal"), object: ck)

        if let qn = ck as? CKQueryNotification {
            print("[CK] QueryNotification reason =", qn.queryNotificationReason.rawValue,
                  "recordID =", qn.recordID?.recordName ?? "nil")
        } else {
            print("[CK] Notification received (type =", ck?.notificationType.rawValue ?? -1, ")")
        }
    }
}
