import Foundation
import UserNotifications

final class UserNotificationPresenter {
    static let shared = UserNotificationPresenter()

    private init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
        }
    }

    func show(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "SLSwitch"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
