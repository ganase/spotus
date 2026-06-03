import SwiftUI

struct LogListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.logs.isEmpty {
                ContentUnavailableView(
                    "ログはまだありません",
                    systemImage: "clock",
                    description: Text("位置情報トリガー、またはPlace画面のテスト通知でログが追加されます。")
                )
            } else {
                List {
                    ForEach(appState.logs) { log in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(appState.placeName(for: log.placeId))
                                    .font(.headline)
                                Spacer()
                                Text(log.userAction.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Text(appState.courseName(for: log.courseId))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(log.message)
                                .font(.body)

                            HStack {
                                Text(log.triggerType.displayName)
                                Text(log.triggeredAt, format: .dateTime.year().month().day().hour().minute())
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Log")
    }
}
