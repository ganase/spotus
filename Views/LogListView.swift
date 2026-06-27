import SwiftUI

struct LogListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isClearConfirmationPresented = false
    @State private var snoozeTarget: TriggerLog?
    @State private var snoozeDate = Date()

    private var orderedLogs: [TriggerLog] {
        appState.logs.sorted { left, right in
            if left.triggeredAt == right.triggeredAt {
                return left.id.uuidString > right.id.uuidString
            }
            return left.triggeredAt > right.triggeredAt
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    activityLogSection
                }
                .padding()
            }
            .onAppear {
                scrollToFocusedLog(using: proxy, animated: false)
            }
            .onChange(of: appState.focusedLogId) { _, _ in
                scrollToFocusedLog(using: proxy, animated: true)
            }
        }
        .themedScreenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !appState.logs.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        isClearConfirmationPresented = true
                    } label: {
                        Label("ログをクリア", systemImage: "trash")
                    }
                }
            }
        }
        .sheet(item: $snoozeTarget) { log in
            NavigationStack {
                SnoozeEditorView(log: log, snoozeDate: $snoozeDate) {
                    appState.snoozeLog(logId: log.id, until: snoozeDate)
                    snoozeTarget = nil
                }
            }
        }
        .confirmationDialog(
            "Logをすべて削除しますか？",
            isPresented: $isClearConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("すべて削除", role: .destructive) {
                appState.clearLogs()
            }

            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("テスト通知の履歴とグラフ集計がクリアされます。")
        }
    }

    private var activityLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appState.logs.isEmpty {
                ContentUnavailableView(
                    "Logはまだありません",
                    systemImage: "list.bullet.clipboard",
                    description: Text("通知を開くと、ここでActの実績を記録できます。")
                )
                .frame(maxWidth: .infinity)
                .surfaceStyle(highlighted: false)
            } else {
                sectionHeader("Log", count: orderedLogs.count)

                ForEach(orderedLogs) { log in
                    logCard(log: log)
                        .id(log.id)
                }
            }
        }
    }

    private func logCard(log: TriggerLog) -> some View {
        let isHighlighted = appState.focusedLogId == log.id
        let isResolved = log.userAction.isResolved

        return VStack(alignment: .leading, spacing: 10) {
            logHeader(log: log, isResolved: isResolved)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    detailRow(
                        title: "通知日時",
                        value: log.triggeredAt.formatted(.dateTime.year().month().day().hour().minute())
                    )

                    if let snoozedUntil = log.snoozedUntil {
                        detailRow(
                            title: "スヌーズ",
                            value: snoozedUntil.formatted(.dateTime.year().month().day().hour().minute())
                        )
                    }

                    Spacer()
                }
            }
            .opacity(isResolved ? 0.68 : 1)

            if log.tasks.isEmpty {
                Text("Actがありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(log.tasks) { task in
                        taskRow(log: log, task: task, isResolved: isResolved)

                        if task.id != log.tasks.last?.id {
                            Divider()
                        }
                    }
                }
                .background(appState.appTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }
                .opacity(isResolved ? 0.58 : 1)
            }

            HStack(spacing: 8) {
                Button {
                    appState.showMap(for: log.placeId)
                } label: {
                    Label("地図", systemImage: "map")
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button {
                    snoozeDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
                    snoozeTarget = log
                } label: {
                    Label("スヌーズ", systemImage: "alarm")
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .disabled(isResolved)

                if isResolved {
                    Button {
                        appState.reopenLog(log.id)
                    } label: {
                        UnifiedEditLabel()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .surfaceStyle(highlighted: isHighlighted)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            appState.focusLog(log.id)
        }
    }

    private func logHeader(log: TriggerLog, isResolved: Bool) -> some View {
        let actSummary = log.tasks.map(\.title).filter { !$0.isEmpty }.joined(separator: " / ")
        let placeName = appState.placeName(for: log.placeId)
        let stepName = actSummary.isEmpty ? log.message : "\(placeName) / \(actSummary)"

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(appState.courseName(for: log.courseId))
                        .font(.caption.weight(.bold))
                        .lineLimit(1)

                    if isResolved {
                        Label("反応済み", systemImage: "checkmark.circle.fill")
                            .font(.caption2.weight(.bold))
                    }
                }

                Text("Step: \(stepName)")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
            }

            Spacer()

            headerStatusBadge(log.userAction)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(logHeaderBackground)
        .foregroundStyle(logHeaderForeground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var logHeaderBackground: Color {
        switch appState.appTheme {
        case .dark:
            return Color.white.opacity(0.16)
        case .gray:
            return Color(red: 0.08, green: 0.18, blue: 0.34)
        case .plain:
            return Color.blue.opacity(0.88)
        }
    }

    private var logHeaderForeground: Color {
        switch appState.appTheme {
        case .dark:
            return .primary
        case .gray, .plain:
            return .white
        }
    }

    private func headerStatusBadge(_ userAction: UserAction) -> some View {
        Label(userAction.displayName, systemImage: userAction.statusIcon)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(headerBadgeBackground)
            .foregroundStyle(headerBadgeForeground)
            .clipShape(Capsule())
    }

    private var headerBadgeBackground: Color {
        switch appState.appTheme {
        case .dark:
            return Color.primary.opacity(0.10)
        case .gray, .plain:
            return Color.white.opacity(0.22)
        }
    }

    private var headerBadgeForeground: Color {
        switch appState.appTheme {
        case .dark:
            return .primary
        case .gray, .plain:
            return .white
        }
    }

    private func taskRow(log: TriggerLog, task: StepTask, isResolved: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                appState.markAvoidedAction(logId: log.id)
            } label: {
                Image(systemName: "hand.thumbsdown")
                    .font(.title3)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isResolved)
            .accessibilityLabel("実行しなかった")

            Text(task.title)
                .font(.subheadline)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .strikethrough(task.isCompleted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                appState.completeStepTask(logId: log.id, taskId: task.id)
            } label: {
                Image(systemName: task.isCompleted ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.title3)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(task.isCompleted ? .blue : .secondary)
            .disabled(isResolved || task.isCompleted)
            .accessibilityLabel(task.isCompleted ? "実行済み" : "実行した")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
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
        case .completed, .didAction:
            return .blue
        case .opened, .mapOpened:
            return .blue
        case .ignored, .avoidedAction, .dismissed, .snoozed:
            return .secondary
        }
    }

    private func scrollToFocusedLog(using proxy: ScrollViewProxy, animated: Bool) {
        guard let logId = appState.focusedLogId else { return }

        let action = {
            proxy.scrollTo(logId, anchor: .top)
        }

        if animated {
            withAnimation {
                action()
            }
        } else {
            action()
        }
    }
}

private enum StepGroupingMode: String, CaseIterable, Identifiable {
    case place
    case act

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .place:
            return "場所ごと"
        case .act:
            return "Actごと"
        }
    }
}

private struct StepDisplayGroup: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let steps: [HabitRule]
}

struct StepsRegistryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isStepCreatorPresented = false
    @State private var groupingMode: StepGroupingMode = .place

    private var registeredStepCount: Int {
        appState.registeredSteps().count
    }

    private var displayGroups: [StepDisplayGroup] {
        switch groupingMode {
        case .place:
            return placeGroups
        case .act:
            return actGroups
        }
    }

    private var placeGroups: [StepDisplayGroup] {
        let grouped = Dictionary(grouping: appState.registeredSteps()) { step in
            appState.rulePlaceDisplayName(step)
        }

        return grouped.keys
            .sorted { $0.localizedCompare($1) == .orderedAscending }
            .map { title in
                let steps = grouped[title] ?? []
                return StepDisplayGroup(
                    id: "place-\(title)",
                    title: title,
                    systemImage: steps.first.map(appState.rulePlaceSystemImage) ?? "mappin",
                    steps: steps
                )
            }
    }

    private var actGroups: [StepDisplayGroup] {
        var grouped: [String: [HabitRule]] = [:]

        for step in appState.registeredSteps() {
            let titles = normalizeActTitles(step.tasks.map(\.title))
            for title in titles {
                grouped[title, default: []].append(step)
            }
        }

        return grouped.keys
            .sorted { $0.localizedCompare($1) == .orderedAscending }
            .map { title in
                StepDisplayGroup(
                    id: "act-\(title)",
                    title: title,
                    systemImage: "list.bullet.rectangle",
                    steps: grouped[title] ?? []
                )
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let focusedStep = appState.focusedStepId.flatMap(appState.rule(for:)) {
                    StepEditorCard(step: focusedStep)
                        .id(focusedStep.id)
                }

                HStack {
                    Text("登録済みSteps")
                        .font(.headline)
                    Spacer()
                    Text("\(registeredStepCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Picker("表示", selection: $groupingMode) {
                    ForEach(StepGroupingMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if registeredStepCount == 0 {
                    ContentUnavailableView(
                        "Stepがありません",
                        systemImage: "checklist",
                        description: Text("Stepを追加して、PlaceとActを組み合わせてください。")
                    )
                    .frame(maxWidth: .infinity)
                    .surfaceStyle(highlighted: false)
                } else {
                    ForEach(displayGroups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label(group.title, systemImage: group.systemImage)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(group.steps.count) Steps")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(group.steps) { step in
                                Button {
                                    appState.openStep(step.id)
                                } label: {
                                    StepRegistryRow(step: step, groupingMode: groupingMode)
                                        .environmentObject(appState)
                                }
                                .buttonStyle(.plain)

                                if step.id != group.steps.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .surfaceStyle(highlighted: false)
                    }
                }
            }
            .padding()
        }
        .themedScreenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isStepCreatorPresented = true
                } label: {
                    Label("Stepを追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isStepCreatorPresented) {
            NavigationStack {
                StepCreateView()
                    .environmentObject(appState)
            }
        }
    }
}

struct DailyOutcomeSummary: Identifiable {
    let date: Date
    let positiveCount: Int
    let negativeCount: Int

    var id: Date { date }
    var hasOutcome: Bool { positiveCount > 0 || negativeCount > 0 }

    static func recentWeek(from logs: [TriggerLog], calendar: Calendar = .current) -> [DailyOutcomeSummary] {
        let today = calendar.startOfDay(for: Date())
        let dates = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }.reversed()

        let grouped = Dictionary(grouping: logs) { log in
            calendar.startOfDay(for: log.triggeredAt)
        }

        return dates.map { date in
            let dayLogs = grouped[date] ?? []
            return DailyOutcomeSummary(
                date: date,
                positiveCount: dayLogs.filter { $0.userAction.outcomeScore > 0 }.count,
                negativeCount: dayLogs.filter { $0.userAction.outcomeScore < 0 }.count
            )
        }
    }
}

private struct StepRegistryRow: View {
    @EnvironmentObject private var appState: AppState
    let step: HabitRule
    let groupingMode: StepGroupingMode

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: rowSystemImage)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(rowTitle)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(step.isEnabled ? "ON" : "OFF")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(step.isEnabled ? .blue : .secondary)
                DisclosureChevron()
            }
        }
        .padding(.vertical, 4)
    }

    private var rowTitle: String {
        switch groupingMode {
        case .place:
            return appState.ruleActTitle(step)
        case .act:
            return appState.rulePlaceDisplayName(step)
        }
    }

    private var rowSystemImage: String {
        switch groupingMode {
        case .place:
            return "list.bullet.rectangle"
        case .act:
            return appState.rulePlaceSystemImage(step)
        }
    }
}

private struct StepCreateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlaceId: UUID?
    @State private var actTitles: [String] = []
    @State private var newActTitle = ""

    private var normalizedActTitles: [String] {
        normalizeActTitles(actTitles)
    }

    private var normalizedNewActTitle: String {
        newActTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        selectedPlaceId != nil && !normalizedActTitles.isEmpty && appState.defaultStepCourseId != nil
    }

    var body: some View {
        Form {
            Section("Place") {
                Picker("Place", selection: $selectedPlaceId) {
                    Text("選択")
                        .tag(UUID?.none)

                    ForEach(appState.places) { place in
                        Label(place.name, systemImage: place.category.systemImage)
                            .tag(Optional(place.id))
                    }
                }
            }

            actSection
        }
        .themedScreenBackground()
        .navigationTitle("Stepを追加")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedPlaceId = selectedPlaceId ?? appState.places.first?.id
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("追加") {
                    guard let selectedPlaceId else { return }
                    appState.addStep(
                        placeId: selectedPlaceId,
                        actTitles: normalizedActTitles
                    )
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
    }

    private var actSection: some View {
        Section {
            if !appState.actTemplates.isEmpty {
                Picker("既存Act", selection: $newActTitle) {
                    Text("選択")
                        .tag("")

                    ForEach(appState.actTemplates) { act in
                        Text(act.title)
                            .tag(act.title)
                    }
                }
            }

            TextField("例: クレアチンを飲む", text: $newActTitle, axis: .vertical)
                .lineLimit(1...3)

            Button {
                addActTitle(normalizedNewActTitle)
            } label: {
                Label("ActをStepに追加", systemImage: "plus.circle")
            }
            .disabled(normalizedNewActTitle.isEmpty)

            if normalizedActTitles.isEmpty {
                Text("このStepに入れるActを追加してください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(normalizedActTitles, id: \.self) { title in
                    HStack {
                        Text(title)
                        Spacer()
                        Button(role: .destructive) {
                            actTitles.removeAll { $0.trimmingCharacters(in: .whitespacesAndNewlines) == title }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        } header: {
            Text("Act")
        } footer: {
            Text("Stepには複数のActを入れられます。")
        }
    }

    private func addActTitle(_ title: String) {
        guard !title.isEmpty else { return }
        if !normalizedActTitles.contains(title) {
            actTitles.append(title)
        }
        newActTitle = ""
    }
}

private struct StepEditorCard: View {
    @EnvironmentObject private var appState: AppState

    let step: HabitRule
    @State private var selectedPlaceId: UUID?
    @State private var actTitles: [String]
    @State private var newActTitle = ""
    @State private var isEnabled: Bool
    @State private var isDeleteConfirmationPresented = false

    init(step: HabitRule) {
        self.step = step
        _selectedPlaceId = State(initialValue: step.placeId)
        _actTitles = State(initialValue: step.tasks.map(\.title))
        _isEnabled = State(initialValue: step.isEnabled)
    }

    private var normalizedActTitles: [String] {
        normalizeActTitles(actTitles)
    }

    private var normalizedNewActTitle: String {
        newActTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Step編集")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }

            Picker("Place", selection: $selectedPlaceId) {
                Text("選択")
                    .tag(UUID?.none)

                ForEach(appState.places) { place in
                    Label(place.name, systemImage: place.category.systemImage)
                        .tag(Optional(place.id))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Act")
                    .font(.subheadline.weight(.semibold))

                if !appState.actTemplates.isEmpty {
                    Picker("既存Act", selection: $newActTitle) {
                        Text("選択")
                            .tag("")

                        ForEach(appState.actTemplates) { act in
                            Text(act.title)
                                .tag(act.title)
                        }
                    }
                }

                ForEach(normalizedActTitles, id: \.self) { title in
                    HStack {
                        Text(title)
                        Spacer()
                        Button(role: .destructive) {
                            actTitles.removeAll { $0.trimmingCharacters(in: .whitespacesAndNewlines) == title }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                HStack {
                    TextField("Actを追加", text: $newActTitle)
                    Button {
                        guard !normalizedNewActTitle.isEmpty else { return }
                        if !normalizedActTitles.contains(normalizedNewActTitle) {
                            actTitles.append(normalizedNewActTitle)
                        }
                        newActTitle = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(normalizedNewActTitle.isEmpty)
                }
            }

            EditorActionBar(
                canSave: selectedPlaceId != nil && !normalizedActTitles.isEmpty,
                onSave: {
                    saveIfPossible()
                    appState.focusedStepId = nil
                },
                onCancel: {
                    resetDraft()
                    appState.focusedStepId = nil
                },
                onDelete: {
                    isDeleteConfirmationPresented = true
                }
            )
        }
        .surfaceStyle(highlighted: true)
        .confirmationDialog(
            "Stepを削除しますか？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                appState.deleteCourseStep(ruleId: step.id)
                appState.focusedStepId = nil
            }

            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(normalizedActTitles.joined(separator: " / "))
        }
        .onAppear {
            resetDraft()
        }
    }

    private func saveIfPossible() {
        guard let selectedPlaceId,
              !normalizedActTitles.isEmpty
        else {
            return
        }

        appState.updateCourseStep(ruleId: step.id, placeId: selectedPlaceId, actTitles: normalizedActTitles)
        appState.setCourseStepEnabled(step.id, isEnabled: isEnabled)
    }

    private func resetDraft() {
        selectedPlaceId = step.placeId
        actTitles = step.tasks.map(\.title)
        isEnabled = step.isEnabled
        newActTitle = ""
    }
}

private struct SnoozeEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let log: TriggerLog
    @Binding var snoozeDate: Date
    let onSave: () -> Void

    var body: some View {
        Form {
            Section {
                DatePicker(
                    "再通知時刻",
                    selection: $snoozeDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            } footer: {
                Text("指定した時刻に同じStepをもう一度通知します。")
            }
        }
        .navigationTitle("スヌーズ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave()
                    dismiss()
                }
            }
        }
    }
}

struct StepsOutcomeChart: View {
    let summaries: [DailyOutcomeSummary]

    private var maxCount: Int {
        max(summaries.map { max($0.positiveCount, $0.negativeCount) }.max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Label("実施", systemImage: "arrow.up.circle.fill")
                    .foregroundStyle(.blue)
                Label("非実施", systemImage: "arrow.down.circle")
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))

            GeometryReader { geometry in
                let barAreaHeight = max(geometry.size.height - 8, 72)
                let halfHeight = max((barAreaHeight - 1) / 2, 30)

                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(summaries) { summary in
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Capsule()
                                    .fill(summary.positiveCount > 0 ? Color.blue : Color.blue.opacity(0.12))
                                    .frame(width: 18, height: barHeight(for: summary.positiveCount, limit: halfHeight))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                    .frame(height: halfHeight)

                    Rectangle()
                        .fill(Color.secondary.opacity(0.24))
                        .frame(height: 1)

                    HStack(alignment: .top, spacing: 8) {
                        ForEach(summaries) { summary in
                            VStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(summary.negativeCount > 0 ? Color.secondary : Color.secondary.opacity(0.12))
                                    .frame(width: 18, height: barHeight(for: summary.negativeCount, limit: halfHeight))
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                    }
                    .frame(height: halfHeight)
                }
            }
            .frame(height: 96)

            HStack(spacing: 8) {
                ForEach(summaries) { summary in
                    VStack(spacing: 2) {
                        Text(summary.date, format: .dateTime.month(.defaultDigits).day())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("\(summary.positiveCount) / -\(summary.negativeCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func barHeight(for count: Int, limit: CGFloat) -> CGFloat {
        guard count > 0 else { return 6 }
        let ratio = CGFloat(count) / CGFloat(maxCount)
        return max(ratio * (limit - 4), 10)
    }
}

struct UnifiedEditLabel: View {
    var title: String = "編集"

    var body: some View {
        Label(title, systemImage: "pencil")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.14))
            .foregroundStyle(.blue)
            .clipShape(Capsule())
    }
}

struct DisclosureChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}

struct EditorActionBar: View {
    let canSave: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: (() -> Void)?

    init(
        canSave: Bool,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.canSave = canSave
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onSave()
            } label: {
                Label("保存", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)

            Button {
                onCancel()
            } label: {
                Label("キャンセル", systemImage: "xmark")
            }
            .buttonStyle(.bordered)

            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("削除", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .font(.subheadline.weight(.semibold))
    }
}

private func normalizeActTitles(_ titles: [String]) -> [String] {
    var seenTitles: Set<String> = []
    var result: [String] = []

    for title in titles.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) {
        guard !title.isEmpty, !seenTitles.contains(title) else { continue }
        seenTitles.insert(title)
        result.append(title)
    }

    return result
}

private extension View {
    func surfaceStyle(highlighted: Bool) -> some View {
        modifier(ThemedSurfaceStyle(highlighted: highlighted))
    }
}

private struct ThemedSurfaceStyle: ViewModifier {
    @EnvironmentObject private var appState: AppState
    let highlighted: Bool

    func body(content: Content) -> some View {
        content
            .padding()
            .background(appState.appTheme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        highlighted ? Color.accentColor.opacity(0.45) : appState.appTheme.elementBorderColor,
                        lineWidth: highlighted ? 1.5 : appState.appTheme.elementBorderWidth
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(appState.appTheme == .gray ? 0.16 : 0.06), radius: 10, x: 0, y: 3)
    }
}
