import SwiftUI

struct LogListView: View {
    @EnvironmentObject private var appState: AppState

    private var pendingLogs: [TriggerLog] {
        appState.logs.filter { !$0.userAction.isResolved }
    }

    private var completedLogs: [TriggerLog] {
        appState.logs.filter { $0.userAction.isResolved }
    }

    private var featuredLog: TriggerLog? {
        if let focusedLogId = appState.focusedLogId,
           let focusedLog = appState.log(for: focusedLogId) {
            return focusedLog
        }

        return pendingLogs.first ?? appState.logs.first
    }

    var body: some View {
        Group {
            if appState.logs.isEmpty {
                ContentUnavailableView(
                    "一歩はまだありません",
                    systemImage: "figure.walk",
                    description: Text("位置情報トリガー、またはPlace画面のテスト通知で一歩が追加されます。")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let featuredLog {
                            featuredCard(log: featuredLog)
                        }

                        if !pendingLogsExcludingFeatured.isEmpty {
                            sectionHeader("まだ返答していない一歩", count: pendingLogsExcludingFeatured.count)

                            ForEach(pendingLogsExcludingFeatured) { log in
                                compactCard(log: log)
                            }
                        }

                        if !completedLogsExcludingFeatured.isEmpty {
                            sectionHeader("完了した一歩", count: completedLogsExcludingFeatured.count)

                            ForEach(completedLogsExcludingFeatured) { log in
                                compactCard(log: log)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("一歩")
        .onAppear {
            if appState.focusedLogId == nil,
               let firstLogId = (pendingLogs.first ?? appState.logs.first)?.id {
                appState.focusLog(firstLogId)
            }
        }
    }

    private var pendingLogsExcludingFeatured: [TriggerLog] {
        guard let featuredLog else { return pendingLogs }
        return pendingLogs.filter { $0.id != featuredLog.id }
    }

    private var completedLogsExcludingFeatured: [TriggerLog] {
        guard let featuredLog else { return completedLogs }
        return completedLogs.filter { $0.id != featuredLog.id }
    }

    private func featuredCard(log: TriggerLog) -> some View {
        let guide = appState.actionGuide(for: log)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("今の一歩")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(appState.placeName(for: log.placeId))
                        .font(.title3.weight(.semibold))

                    Text(appState.courseName(for: log.courseId))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusBadge(log.userAction)
            }

            Text(log.message)
                .font(.body)

            guidanceBlock(
                title: "やること",
                systemImage: "checkmark.circle.fill",
                tint: .green,
                text: guide.doText
            )

            guidanceBlock(
                title: "控えること",
                systemImage: "hand.raised.fill",
                tint: .orange,
                text: guide.avoidText
            )

            HStack(spacing: 10) {
                Button {
                    appState.markDidAction(logId: log.id)
                } label: {
                    Label("実行できた", systemImage: "hand.thumbsup.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(log.userAction.isResolved)

                Button {
                    appState.markAvoidedAction(logId: log.id)
                } label: {
                    Label("見送れた", systemImage: "hand.thumbsup.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(log.userAction.isResolved)
            }

            HStack {
                Label(log.triggerType.displayName, systemImage: "bell.badge")
                Spacer()
                Text(log.triggeredAt, format: .dateTime.year().month().day().hour().minute())
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button {
                appState.showMap(for: log.placeId)
            } label: {
                Label("登録地点を地図で見る", systemImage: "map")
            }
            .buttonStyle(.bordered)
        }
        .surfaceStyle(highlighted: true)
    }

    private func compactCard(log: TriggerLog) -> some View {
        let guide = appState.actionGuide(for: log)

        return Button {
            appState.focusLog(log.id)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.placeName(for: log.placeId))
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(appState.courseName(for: log.courseId))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    statusBadge(log.userAction)
                }

                Text(guide.doText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                HStack {
                    Text(log.triggeredAt, format: .dateTime.month().day().hour().minute())
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .surfaceStyle(highlighted: appState.focusedLogId == log.id)
    }

    private func guidanceBlock(title: String, systemImage: String, tint: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func statusBadge(_ userAction: UserAction) -> some View {
        Label(userAction.displayName, systemImage: userAction.statusIcon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor(for: userAction).opacity(0.14))
            .foregroundStyle(statusColor(for: userAction))
            .clipShape(Capsule())
    }

    private func statusColor(for userAction: UserAction) -> Color {
        switch userAction {
        case .completed, .didAction, .avoidedAction:
            return .green
        case .opened, .mapOpened:
            return .blue
        case .dismissed:
            return .orange
        case .ignored:
            return .secondary
        }
    }
}

private extension View {
    func surfaceStyle(highlighted: Bool) -> some View {
        self
            .padding()
            .background(.background)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(highlighted ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }
}
