import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var isAppInfoPresented = false

    private var activeCourses: [HabitCourse] {
        appState.courses.filter(\.isEnabled)
    }

    private var isLocationReady: Bool {
        appState.locationService.authorizationStatus == .authorizedAlways
    }

    private var isNotificationReady: Bool {
        appState.notificationService.authorizationStatus.allowsHabitNotifications
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mapCard
                courseCard
                permissionCard
            }
            .padding()
        }
        .navigationTitle("Spotus")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isAppInfoPresented = true
                } label: {
                    Label("情報", systemImage: "info.circle")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.requestCurrentLocation()
                } label: {
                    Label("現在地", systemImage: "location")
                }
            }
        }
        .sheet(isPresented: $isAppInfoPresented) {
            AppInfoView()
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("権限")
                .font(.headline)

            if !isLocationReady || !isNotificationReady {
                setupGuidance
            }

            StatusRow(
                title: "位置情報",
                value: appState.locationService.authorizationStatus.habitRouteDisplayName,
                systemImage: "location.fill",
                isHealthy: isLocationReady
            )

            StatusRow(
                title: "通知",
                value: appState.notificationService.authorizationStatus.habitRouteDisplayName,
                systemImage: "bell.fill",
                isHealthy: isNotificationReady
            )

            HStack {
                if let action = locationPermissionAction {
                    Button {
                        handleLocationPermissionAction()
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                    .buttonStyle(.bordered)
                }

                if let action = notificationPermissionAction {
                    Button {
                        handleNotificationPermissionAction()
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if appState.locationService.authorizationStatus == .authorizedWhenInUse {
                Label("バックグラウンド通知には「常に許可」が必要です。", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .cardStyle()
    }

    private var setupGuidance: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("到着通知を使う準備", systemImage: "checklist")
                .font(.subheadline.weight(.semibold))

            Text("Spotusは、登録地点への到着判定に位置情報を使い、通知は端末内のローカル通知として表示します。")
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 6) {
                setupStep(
                    number: 1,
                    text: "まず位置情報を許可し、地点登録や現在地確認を使えるようにします。"
                )
                setupStep(
                    number: 2,
                    text: "バックグラウンド到着通知を受けるには、位置情報を「常に許可」にします。"
                )
                setupStep(
                    number: 3,
                    text: "最後に通知を許可すると、Spotusを閉じていても到着時に通知できます。"
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var courseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("有効なコース")
                    .font(.headline)
                Spacer()
                Text("\(activeCourses.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if activeCourses.isEmpty {
                Text("Course画面で生活改善コースをONにできます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(activeCourses.prefix(4)) { course in
                    Label(course.name, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.primary)
                }
            }
        }
        .cardStyle()
    }

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("登録地点")
                    .font(.headline)
                Spacer()
                Text("\(appState.locationService.monitoredRegionCount)/20 監視中")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if appState.places.isEmpty {
                Text("Place画面で自宅、駅、職場などを登録できます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                PlacesOverviewMap(places: appState.places.filter(\.isEnabled))
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                ForEach(appState.places.prefix(5)) { place in
                    HStack {
                        Label(place.name, systemImage: place.category.systemImage)
                        Spacer()
                        Button {
                            appState.showMap(for: place.id)
                        } label: {
                            Image(systemName: "map")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("\(place.name)を地図で見る")

                        Text(place.isEnabled ? "ON" : "OFF")
                            .font(.caption)
                            .foregroundStyle(place.isEnabled ? .green : .secondary)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var locationPermissionAction: PermissionAction? {
        switch appState.locationService.authorizationStatus {
        case .notDetermined:
            return PermissionAction(title: "位置情報を許可", systemImage: "location.circle")
        case .authorizedWhenInUse:
            return PermissionAction(title: "常に許可へ進む", systemImage: "location.badge.plus")
        case .restricted, .denied:
            return PermissionAction(title: "位置情報の設定を開く", systemImage: "gearshape")
        case .authorizedAlways:
            return nil
        @unknown default:
            return PermissionAction(title: "位置情報の設定を開く", systemImage: "gearshape")
        }
    }

    private var notificationPermissionAction: PermissionAction? {
        switch appState.notificationService.authorizationStatus {
        case .notDetermined:
            return PermissionAction(title: "通知を許可", systemImage: "bell.circle")
        case .denied:
            return PermissionAction(title: "通知の設定を開く", systemImage: "gearshape")
        case .authorized, .provisional, .ephemeral:
            return nil
        @unknown default:
            return PermissionAction(title: "通知の設定を開く", systemImage: "gearshape")
        }
    }

    private func handleLocationPermissionAction() {
        switch appState.locationService.authorizationStatus {
        case .notDetermined:
            appState.requestForegroundLocationPermission()
        case .authorizedWhenInUse:
            appState.requestBackgroundLocationPermission()
        case .restricted, .denied:
            openAppSettings()
        case .authorizedAlways:
            break
        @unknown default:
            openAppSettings()
        }
    }

    private func handleNotificationPermissionAction() {
        switch appState.notificationService.authorizationStatus {
        case .notDetermined:
            appState.requestNotificationPermission()
        case .denied:
            openAppSettings()
        case .authorized, .provisional, .ephemeral:
            break
        @unknown default:
            openAppSettings()
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func setupStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .leading)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct PlacesOverviewMap: View {
    let places: [Place]
    @State private var position: MapCameraPosition

    init(places: [Place]) {
        self.places = places
        _position = State(initialValue: PlacesOverviewMap.initialPosition(for: places))
    }

    var body: some View {
        Map(position: $position) {
            UserAnnotation()

            ForEach(places) { place in
                MapCircle(center: place.coordinate, radius: place.radius)
                    .foregroundStyle(Color.accentColor.opacity(0.12))
                    .stroke(Color.accentColor.opacity(0.7), lineWidth: 1)

                Marker(place.name, systemImage: place.category.systemImage, coordinate: place.coordinate)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }

    private static func initialPosition(for places: [Place]) -> MapCameraPosition {
        guard let firstPlace = places.first else {
            return .automatic
        }

        let coordinates = places.map(\.coordinate)
        let minLatitude = coordinates.map(\.latitude).min() ?? firstPlace.latitude
        let maxLatitude = coordinates.map(\.latitude).max() ?? firstPlace.latitude
        let minLongitude = coordinates.map(\.longitude).min() ?? firstPlace.longitude
        let maxLongitude = coordinates.map(\.longitude).max() ?? firstPlace.longitude
        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let northSouthMeters = max(CLLocation(latitude: minLatitude, longitude: center.longitude).distance(
            from: CLLocation(latitude: maxLatitude, longitude: center.longitude)
        ), 700)
        let eastWestMeters = max(CLLocation(latitude: center.latitude, longitude: minLongitude).distance(
            from: CLLocation(latitude: center.latitude, longitude: maxLongitude)
        ), 700)

        return .region(
            MKCoordinateRegion(
                center: center,
                latitudinalMeters: northSouthMeters * 1.6,
                longitudinalMeters: eastWestMeters * 1.6
            )
        )
    }
}

struct PlaceMapDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let place: Place
    @State private var position: MapCameraPosition

    init(place: Place) {
        self.place = place
        let spanMeters = max(place.radius * 5, 700)
        _position = State(initialValue: .region(
            MKCoordinateRegion(
                center: place.coordinate,
                latitudinalMeters: spanMeters,
                longitudinalMeters: spanMeters
            )
        ))
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                UserAnnotation()

                Marker(place.name, systemImage: place.category.systemImage, coordinate: place.coordinate)

                MapCircle(center: place.coordinate, radius: place.radius)
                    .foregroundStyle(Color.accentColor.opacity(0.16))
                    .stroke(Color.accentColor, lineWidth: 2)
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.name)
                        .font(.headline)
                    Text("\(place.category.displayName) / 半径 \(Int(place.radius))m")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial)
            }
            .navigationTitle("地図")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.requestCurrentLocation()
                    } label: {
                        Label("現在地", systemImage: "location")
                    }
                }
            }
        }
    }
}

private struct StatusRow: View {
    let title: String
    let value: String
    let systemImage: String
    let isHealthy: Bool

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isHealthy ? .green : .orange)
        }
    }
}

private struct PermissionAction {
    let title: String
    let systemImage: String
}

private struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "バージョン \(version) / ビルド \(build)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Spotusについて") {
                    Text("Spotusは、登録地点への到着や離脱をきっかけに、その場で取り組みやすい小さな習慣を通知するアプリです。")
                    Text("確認しやすいように、Place画面では各地点を左にスワイプして通知テストを実行できます。")
                }

                Section("権限の使い方") {
                    Label("位置情報は、登録地点への到着判定と地図上の現在地表示に使います。", systemImage: "location.fill")
                    Label("位置情報を「常に許可」にすると、Spotusを閉じていても到着通知を受け取れます。", systemImage: "location.badge.plus")
                    Label("通知は、端末内のローカル通知として表示します。", systemImage: "bell.badge.fill")
                }

                Section("プライバシー") {
                    Text("登録地点、コース設定、一歩の履歴は端末内のApplication Supportに保存します。")
                    Text("このMVPはサーバー送信やアカウント連携を持たず、位置情報や一歩の履歴を外部へアップロードしません。")
                }

                Section("サポート") {
                    Text("通知が届かない場合は、位置情報が「常に許可」になっているか、通知が許可されているかを確認してください。")
                    Text("審査や動作確認では、Place画面の「テスト」で通知経路をすぐ確認できます。")
                }

                Section {
                    Text(versionText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

private extension UNAuthorizationStatus {
    var allowsHabitNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }
}
