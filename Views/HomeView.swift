import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var isSettingsPresented = false

    private var isLocationReady: Bool {
        appState.locationService.authorizationStatus == .authorizedAlways
    }

    private var isNotificationReady: Bool {
        appState.notificationService.authorizationStatus.allowsHabitNotifications
    }

    private var chartSummaries: [DailyOutcomeSummary] {
        DailyOutcomeSummary.recentWeek(from: appState.logs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                outcomeChartCard
                mapCard
                courseCard
            }
            .padding()
        }
        .themedScreenBackground()
        .navigationTitle("lifeloop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isSettingsPresented = true
                } label: {
                    Label("設定", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .environmentObject(appState)
        }
    }

    private var outcomeChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("日ごとの実施状況")
                    .font(.headline)
                Spacer()
                Image(systemName: "chart.bar.xaxis")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            if chartSummaries.contains(where: \.hasOutcome) {
                StepsOutcomeChart(summaries: chartSummaries)
            } else {
                ContentUnavailableView(
                    "まだ集計できるLogはありません",
                    systemImage: "chart.bar",
                    description: Text("通知後にActへ反応すると、ここに日ごとの実績が表示されます。")
                )
                .frame(maxWidth: .infinity)
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
            }
        }
        .cardStyle()
    }

    private var courseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Course")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    CourseCreatorView()
                        .environmentObject(appState)
                } label: {
                    Image(systemName: "plus")
                }
            }

            if appState.courses.isEmpty {
                Text("Courseを作成すると、Placeに着いた時にStepが通知されます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(appState.courses) { course in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(appState.courseSteps(for: course.id)) { step in
                                    Button {
                                        appState.openStep(step.id)
                                    } label: {
                                        HStack {
                                            Label(appState.rulePlaceDisplayName(step), systemImage: appState.rulePlaceSystemImage(step))
                                                .lineLimit(1)
                                            Spacer()
                                            Text("\(step.tasks.count) Act")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 4)
                                }

                                NavigationLink {
                                    CourseSettingsView(courseId: course.id)
                                        .environmentObject(appState)
                                } label: {
                                    UnifiedEditLabel()
                                }
                                .padding(.top, 4)
                            }
                            .padding(.top, 8)
                        } label: {
                            CourseHomeRow(course: course, stepCount: appState.courseSteps(for: course.id).count)
                        }
                        .padding(12)
                        .background(appState.appTheme.subtleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(appState.appTheme.elementBorderColor, lineWidth: appState.appTheme.elementBorderWidth)
                        }
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

private struct CourseHomeRow: View {
    let course: HabitCourse
    let stepCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(course.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(course.isEnabled ? "ON" : "OFF")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(course.isEnabled ? .blue : .secondary)
            }

            HStack(spacing: 10) {
                Label("\(stepCount) Steps", systemImage: "checklist")
                Label(course.weekdayType.displayName, systemImage: "calendar")
                Label(course.timeBlock.displayName, systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
                .foregroundStyle(isHealthy ? .blue : .secondary)
        }
    }
}

private struct PermissionAction {
    let title: String
    let systemImage: String
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "バージョン \(version) / ビルド \(build)"
    }

    private var isLocationReady: Bool {
        appState.locationService.authorizationStatus == .authorizedAlways
    }

    private var isNotificationReady: Bool {
        appState.notificationService.authorizationStatus.allowsHabitNotifications
    }

    var body: some View {
        NavigationStack {
            List {
                Section("権限") {
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

                    if let action = locationPermissionAction {
                        Button {
                            handleLocationPermissionAction()
                        } label: {
                            Label(action.title, systemImage: action.systemImage)
                        }
                    }

                    if let action = notificationPermissionAction {
                        Button {
                            handleNotificationPermissionAction()
                        } label: {
                            Label(action.title, systemImage: action.systemImage)
                        }
                    }

                    Button {
                        appState.requestCurrentLocation()
                    } label: {
                        Label("現在地を更新", systemImage: "location")
                    }
                }

                Section("デザイン") {
                    Picker("デザイン", selection: $appState.appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Label(theme.displayName, systemImage: theme.systemImage)
                                .tag(theme)
                        }
                    }
                }

                Section("lifeloopについて") {
                    Text("lifeloopは、登録地点への到着や離脱をきっかけに、その場で取り組みやすい小さな習慣を通知するアプリです。")
                    Text("確認しやすいように、Place画面では各地点を左にスワイプして通知テストを実行できます。")
                }

                Section("権限の使い方") {
                    Label("位置情報は、登録地点への到着判定と地図上の現在地表示に使います。", systemImage: "location.fill")
                    Label("位置情報を「常に許可」にすると、lifeloopを閉じていても到着通知を受け取れます。", systemImage: "location.badge.plus")
                    Label("通知は、端末内のローカル通知として表示します。", systemImage: "bell.badge.fill")
                }

                Section("プライバシー") {
                    Text("登録地点、Act設定、Stepsの履歴は端末内のApplication Supportに保存します。")
                    Text("このMVPはサーバー送信やアカウント連携を持たず、位置情報やStepsの履歴を外部へアップロードしません。")
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
            .navigationTitle("設定")
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
}

private struct ThemeMenuButton: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Menu {
            Picker("デザイン", selection: $appState.appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.displayName, systemImage: theme.systemImage)
                        .tag(theme)
                }
            }
        } label: {
            Label("デザイン", systemImage: "paintpalette")
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        modifier(ThemedCardStyle())
    }
}

private struct ThemedCardStyle: ViewModifier {
    @EnvironmentObject private var appState: AppState

    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(appState.appTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(appState.appTheme.elementBorderColor, lineWidth: appState.appTheme.elementBorderWidth)
            }
            .shadow(color: .black.opacity(appState.appTheme == .gray ? 0.18 : 0.08), radius: 8, x: 0, y: 2)
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
