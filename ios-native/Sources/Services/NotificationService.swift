import Foundation
import UserNotifications

protocol NotificationScheduling: AnyObject {
    func schedule(id: Int64, when: Date, title: String, body: String) async throws
    func cancel(id: Int64) async
}

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let categoryIdentifier = "koto_actions"
    private let center = UNUserNotificationCenter.current()
    private let repository: MemoRepository

    var onEditRequested: ((Int64) -> Void)?

    init(repository: MemoRepository) {
        self.repository = repository
        super.init()
        center.delegate = self
    }

    func configure() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }
        #endif
        let granted = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        if granted == true {
            await registerActions()
        }
    }

    private func registerActions() async {
        let done = UNNotificationAction(identifier: "done", title: "完了", options: [.authenticationRequired])
        let snooze = UNNotificationAction(identifier: "snooze", title: "スヌーズ +15分", options: [])
        let edit = UNNotificationAction(identifier: "edit", title: "編集を開く", options: [.foreground])
        let category = UNNotificationCategory(identifier: Self.categoryIdentifier, actions: [done, snooze, edit], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    func schedule(id: Int64, when: Date, title: String, body: String) async throws {
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: when)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = ["memoId": id]
        let request = UNNotificationRequest(identifier: "\(id)", content: content, trigger: trigger)
        try await center.add(request)
    }

    func cancel(id: Int64) async {
        center.removePendingNotificationRequests(withIdentifiers: ["\(id)"])
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { completionHandler(); return }
            let memoId = Int64(response.notification.request.identifier) ?? Int64(response.notification.request.content.userInfo["memoId"] as? Int ?? -1)
            guard memoId > 0 else {
                completionHandler()
                return
            }
            switch response.actionIdentifier {
            case "done":
                try? self.repository.markDone(id: memoId, done: true)
            case "snooze":
                let newDate = Date().addingTimeInterval(15 * 60)
                if var memo = try? self.repository.memo(for: memoId) {
                    memo.reminderAt = newDate
                    _ = try? self.repository.updateMemo(memo)
                    try? await self.schedule(id: memoId, when: newDate, title: "すぐメモ リマインダー", body: memo.text)
                }
            case "edit", UNNotificationDefaultActionIdentifier:
                self.onEditRequested?(memoId)
            default:
                break
            }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        #if os(iOS)
        return [.alert, .badge, .sound]
        #else
        return [.sound]
        #endif
    }
}

extension NotificationService: NotificationScheduling {}
