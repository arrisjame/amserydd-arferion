import UIKit
import UserNotifications

@MainActor
final class TimeBankAlertService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TimeBankAlertService()

    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    func configure() {
        notificationCenter.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }

            _ = try? await notificationCenter.requestAuthorization(options: [.alert, .sound])
        }
    }

    func notifyTimeExpired() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        let content = UNMutableNotificationContent()
        content.title = "Time Bank"
        content.body = "Your available time has reached zero."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "time-bank-empty-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        Task {
            try? await notificationCenter.add(request)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
