import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    private lazy var center: UNUserNotificationCenter? = {
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog("NotificationManager: no bundle identifier — notifications disabled")
            return nil
        }
        return UNUserNotificationCenter.current()
    }()

    func requestAuthorization() async {
        _ = try? await center?.requestAuthorization(options: [.alert, .sound])
    }

    func postThresholdAlert(title: String, body: String) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil)
        center.add(request)
    }
}
