import CoreLocation
import SwiftUI
import UserNotifications

@main
struct SpotusApp: App {
    @StateObject private var permissionRequester = PermissionRequester()

    var body: some Scene {
        WindowGroup {
            PermissionStatusView(permissionRequester: permissionRequester)
                .task {
                    permissionRequester.requestLaunchPermissions()
                }
        }
    }
}

final class PermissionRequester: NSObject, ObservableObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus
    @Published private(set) var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var monitoredRegionCount = 0
    @Published private(set) var lastEnteredPlaceName: String?
    @Published private(set) var lastNotificationMessage: String?

    private static let regionIdentifierPrefix = "spotus-place-"
    private let locationManager = CLLocationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    private var shouldRequestNotificationAfterLocation = false
    private var didRequestLaunchPermissions = false
    private var didRequestNotificationAuthorization = false

    override init() {
        locationAuthorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        notificationCenter.delegate = self
        refreshNotificationStatus()
    }

    func requestLaunchPermissions() {
        guard !didRequestLaunchPermissions else { return }
        didRequestLaunchPermissions = true

        locationAuthorizationStatus = locationManager.authorizationStatus

        if locationAuthorizationStatus == .notDetermined {
            shouldRequestNotificationAfterLocation = true
            locationManager.requestWhenInUseAuthorization()
        } else {
            syncRegionMonitoring()
            requestNotificationAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.locationAuthorizationStatus = manager.authorizationStatus
            self.syncRegionMonitoring()

            guard self.shouldRequestNotificationAfterLocation,
                  manager.authorizationStatus != .notDetermined
            else {
                return
            }

            self.shouldRequestNotificationAfterLocation = false
            self.requestNotificationAuthorization()
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let place = place(for: region.identifier) else { return }
        let message = notificationMessage(for: place)
        deliverNotification(for: place, message: message)

        DispatchQueue.main.async { [weak self] in
            self?.lastEnteredPlaceName = place.name
            self?.lastNotificationMessage = message
        }
    }

    private func syncRegionMonitoring() {
        stopMonitoringSpotusRegions()

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self),
              locationAuthorizationStatus == .authorizedAlways || locationAuthorizationStatus == .authorizedWhenInUse
        else {
            monitoredRegionCount = 0
            return
        }

        let places = Place.initialPlaces.prefix(20)

        for place in places {
            let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            let region = CLCircularRegion(
                center: center,
                radius: normalizedRadius(place.radius),
                identifier: Self.regionIdentifierPrefix + place.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            locationManager.startMonitoring(for: region)
        }

        monitoredRegionCount = places.count
    }

    private func stopMonitoringSpotusRegions() {
        for region in locationManager.monitoredRegions where region.identifier.hasPrefix(Self.regionIdentifierPrefix) {
            locationManager.stopMonitoring(for: region)
        }
    }

    private func normalizedRadius(_ radius: Double) -> CLLocationDistance {
        let requestedRadius = max(radius, 50)

        guard locationManager.maximumRegionMonitoringDistance > 0 else {
            return requestedRadius
        }

        return min(requestedRadius, locationManager.maximumRegionMonitoringDistance)
    }

    private func place(for regionIdentifier: String) -> Place? {
        guard regionIdentifier.hasPrefix(Self.regionIdentifierPrefix) else { return nil }

        let uuidString = String(regionIdentifier.dropFirst(Self.regionIdentifierPrefix.count))
        guard let placeId = UUID(uuidString: uuidString) else { return nil }

        return Place.initialPlaces.first { $0.id == placeId }
    }

    private func deliverNotification(for place: Place, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(place.name)に到着しました"
        content.body = message
        content.sound = .default
        content.userInfo = ["placeId": place.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "spotus-\(place.id.uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }

    private func notificationMessage(for place: Place) -> String {
        switch place.category {
        case .station:
            return "駅に到着しました。今日は10ページだけ読んでみましょう。"
        case .gym:
            return "ジムに到着しました。まず5分だけ体を動かしましょう。"
        case .home:
            return "自宅に到着しました。今日の小さな習慣を1つだけ片付けましょう。"
        default:
            return "\(place.name)に到着しました。小さく習慣を進めましょう。"
        }
    }

    private func requestNotificationAuthorization() {
        guard !didRequestNotificationAuthorization else { return }
        didRequestNotificationAuthorization = true

        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, _ in
            self?.refreshNotificationStatus()
        }
    }

    private func refreshNotificationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationAuthorizationStatus = settings.authorizationStatus
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

struct PermissionStatusView: View {
    @ObservedObject var permissionRequester: PermissionRequester

    var body: some View {
        NavigationStack {
            List {
                Section("許可") {
                    LabeledContent("位置情報", value: permissionRequester.locationAuthorizationStatus.displayName)
                    LabeledContent("通知", value: permissionRequester.notificationAuthorizationStatus.displayName)
                    LabeledContent("監視地点", value: "\(permissionRequester.monitoredRegionCount)/\(Place.initialPlaces.count)")
                    LabeledContent("直近イベント", value: permissionRequester.lastEnteredPlaceName.map { "\($0)に入りました" } ?? "なし")
                    LabeledContent("直近通知", value: permissionRequester.lastNotificationMessage ?? "なし")
                }

                Section("登録地点") {
                    ForEach(Place.initialPlaces) { place in
                        HStack(spacing: 12) {
                            Image(systemName: place.category.systemImage)
                                .frame(width: 28)
                                .foregroundStyle(Color.accentColor)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name)
                                    .font(.headline)
                                Text("\(place.category.displayName) / 半径 \(Int(place.radius))m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Spotus")
        }
    }
}

private extension Place {
    static let initialPlaces = [
        Place(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "自宅",
            latitude: 35.681236,
            longitude: 139.767125,
            radius: 150,
            category: .home
        ),
        Place(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "最寄駅",
            latitude: 35.681382,
            longitude: 139.766084,
            radius: 150,
            category: .station
        ),
        Place(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "ジム",
            latitude: 35.682839,
            longitude: 139.759455,
            radius: 150,
            category: .gym
        )
    ]
}

private extension CLAuthorizationStatus {
    var displayName: String {
        switch self {
        case .notDetermined:
            return "未確認"
        case .restricted:
            return "制限中"
        case .denied:
            return "拒否"
        case .authorizedAlways:
            return "常に許可"
        case .authorizedWhenInUse:
            return "使用中のみ許可"
        @unknown default:
            return "不明"
        }
    }
}

private extension UNAuthorizationStatus {
    var displayName: String {
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
