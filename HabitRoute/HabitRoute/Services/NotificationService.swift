import Foundation
import UserNotifications

final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let categoryIdentifier = "HABIT_ROUTE_ACTIONS"
    static let completedActionIdentifier = "HABIT_ROUTE_COMPLETED"

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var onResponse: ((UUID, UserAction) -> Void)?

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
        configureCategories()
        refreshAuthorizationStatus()
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, _ in
            self?.refreshAuthorizationStatus()
        }
    }

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func deliver(title: String, body: String, logId: UUID, placeId: UUID, courseId: UUID?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [
            "logId": logId.uuidString,
            "placeId": placeId.uuidString,
            "courseId": courseId?.uuidString ?? ""
        ]

        // A nil trigger delivers immediately. Region Monitoring already supplied the timing.
        let request = UNNotificationRequest(identifier: logId.uuidString, content: content, trigger: nil)
        center.add(request)
    }

    private func configureCategories() {
        let completed = UNNotificationAction(
            identifier: Self.completedActionIdentifier,
            title: "やった",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [completed],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([category])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard let logIdString = response.notification.request.content.userInfo["logId"] as? String,
              let logId = UUID(uuidString: logIdString)
        else {
            return
        }

        let action: UserAction
        switch response.actionIdentifier {
        case Self.completedActionIdentifier:
            action = .completed
        case UNNotificationDismissActionIdentifier:
            action = .dismissed
        default:
            action = .opened
        }

        DispatchQueue.main.async { [weak self] in
            self?.onResponse?(logId, action)
        }
    }
}

extension UNAuthorizationStatus {
    var habitRouteDisplayName: String {
        switch self {
        case .notDetermined:
            return "未確認"
        case .denied:
            return "拒否"
        case .authorized:
            return "許可"
        case .provisional:
            return "仮許可"
        case .ephemeral:
            return "一時許可"
        @unknown default:
            return "不明"
        }
    }
}
