import CoreLocation
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    private var activeCourses: [HabitCourse] {
        appState.courses.filter(\.isEnabled)
    }

    private var recentLogs: [TriggerLog] {
        Array(appState.logs.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                permissionCard
                courseCard
                placeCard
                todayLogCard
            }
            .padding()
        }
        .navigationTitle("Spotus")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.requestCurrentLocation()
                } label: {
                    Label("現在地", systemImage: "location")
                }
            }
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("権限")
                .font(.headline)

            StatusRow(
                title: "位置情報",
                value: appState.locationService.authorizationStatus.habitRouteDisplayName,
                systemImage: "location.fill",
                isHealthy: appState.locationService.authorizationStatus == .authorizedAlways
            )

            StatusRow(
                title: "通知",
                value: appState.notificationService.authorizationStatus.habitRouteDisplayName,
                systemImage: "bell.fill",
                isHealthy: appState.notificationService.authorizationStatus == .authorized
            )

            HStack {
                Button {
                    appState.requestLocationPermission()
                } label: {
                    Label("位置情報を許可", systemImage: "location.circle")
                }
                .buttonStyle(.bordered)

                Button {
                    appState.requestNotificationPermission()
                } label: {
                    Label("通知を許可", systemImage: "bell.circle")
                }
                .buttonStyle(.bordered)
            }

            if appState.locationService.authorizationStatus != .authorizedAlways {
                Label("バックグラウンド通知には「常に許可」が必要です。", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .cardStyle()
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

    private var placeCard: some View {
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
                ForEach(appState.places.prefix(5)) { place in
                    HStack {
                        Label(place.name, systemImage: place.category.systemImage)
                        Spacer()
                        Text(place.isEnabled ? "ON" : "OFF")
                            .font(.caption)
                            .foregroundStyle(place.isEnabled ? .green : .secondary)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var todayLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日通知された行動")
                .font(.headline)

            if recentLogs.isEmpty {
                Text("まだ通知ログはありません。Place画面のテスト通知で動作確認できます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.message)
                            .font(.subheadline)
                        HStack {
                            Text(appState.placeName(for: log.placeId))
                            Text(log.userAction.displayName)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
        }
        .cardStyle()
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
