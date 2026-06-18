import Foundation
import UserNotifications

final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let categoryIdentifier = "SPOTUS_ACTIONS"
    static let mapActionIdentifier = "SPOTUS_SHOW_MAP"

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var onResponse: ((UUID, UUID?, UserAction) -> Void)?

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

    func deliver(title: String, subtitle: String, body: String, logId: UUID, placeId: UUID, courseId: UUID?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
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
        let showMap = UNNotificationAction(
            identifier: Self.mapActionIdentifier,
            title: "地図で見る",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [showMap],
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

        let userInfo = response.notification.request.content.userInfo

        guard let logIdString = userInfo["logId"] as? String,
              let logId = UUID(uuidString: logIdString)
        else {
            return
        }

        let placeId = (userInfo["placeId"] as? String).flatMap(UUID.init(uuidString:))

        let action: UserAction
        switch response.actionIdentifier {
        case Self.mapActionIdentifier:
            action = .mapOpened
        case UNNotificationDismissActionIdentifier:
            action = .dismissed
        default:
            action = .opened
        }

        DispatchQueue.main.async { [weak self] in
            self?.onResponse?(logId, placeId, action)
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
