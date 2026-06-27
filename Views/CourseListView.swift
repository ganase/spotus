import SwiftUI

struct CourseListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isCourseCreatorPresented = false

    var body: some View {
        List {
            Section {
                ForEach(appState.courses) { course in
                    NavigationLink {
                        CourseSettingsView(courseId: course.id)
                    } label: {
                        CourseSummaryView(
                            course: course,
                            stepCount: appState.courseSteps(for: course.id).count
                        )
                    }
                }
            } footer: {
                Text("CourseがONで、曜日と時間帯が一致しているとき、Course内のStepに登録したPlaceへ入ると、そのStepのActが通知されます。")
            }
        }
        .themedScreenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCourseCreatorPresented = true
                } label: {
                    Label("コースを作成", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCourseCreatorPresented) {
            NavigationStack {
                CourseCreatorView()
                    .environmentObject(appState)
            }
        }
    }

}

private struct CourseSummaryView: View {
    let course: HabitCourse
    let stepCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(course.name)
                    .font(.headline)

                Spacer()

                Text(course.isEnabled ? "ON" : "OFF")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(course.isEnabled ? .blue : .secondary)
            }

            Text(course.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Label(course.weekdayType.displayName, systemImage: "calendar")
                Label(course.timeBlock.displayName, systemImage: "clock")
                Label("\(stepCount) Steps", systemImage: "checklist")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            Text(course.targetCategories.map(\.displayName).joined(separator: " / "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct CourseSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isStepCreatorPresented = false
    @State private var editingStep: HabitRule?

    let courseId: UUID

    var body: some View {
        Form {
            if appState.course(for: courseId) != nil {
                Section {
                    TextField("Course名", text: nameBinding, axis: .vertical)
                        .lineLimit(1...2)

                    TextField("説明", text: descriptionBinding, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Course")
                } footer: {
                    Text("ActそのものはAct画面で編集します。ここではCourseの名前、使う曜日、時間帯、通知するStepを調整します。")
                }

                Section("状態") {
                    Toggle("このCourseを使う", isOn: enabledBinding)
                }

                Section("曜日") {
                    Picker("曜日", selection: weekdayTypeBinding) {
                        ForEach(WeekdayType.allCases) { weekdayType in
                            Text(weekdayType.displayName)
                                .tag(weekdayType)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("時間帯") {
                    Picker("時間帯", selection: timeBlockBinding) {
                        ForEach(TimeBlock.allCases) { timeBlock in
                            Text(timeBlock.displayName)
                                .tag(timeBlock)
                        }
                    }
                }

                Section {
                    let steps = appState.courseSteps(for: courseId)

                    if steps.isEmpty {
                        ContentUnavailableView(
                            "Stepがありません",
                            systemImage: "checklist",
                            description: Text("Stepを追加して、PlaceとActを1つずつ組み合わせてください。")
                        )
                    } else {
                        ForEach(steps) { step in
                            Button {
                                editingStep = step
                            } label: {
                                CourseStepRowView(step: step)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        isStepCreatorPresented = true
                    } label: {
                        Label("Stepを追加", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Steps")
                } footer: {
                    Text("StepはPlaceとActの組み合わせです。自宅には接種系、店やレストランには外食抑制、のように分けて設定できます。")
                }
            } else {
                ContentUnavailableView("Courseが見つかりません", systemImage: "figure.walk.motion")
            }
        }
        .themedScreenBackground()
        .navigationTitle("Course編集")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isStepCreatorPresented) {
            NavigationStack {
                CourseStepEditorView(
                    title: "Stepを追加",
                    initialPlaceId: appState.places.first?.id,
                    initialActTitles: [],
                    initialIsEnabled: true,
                    saveTitle: "追加",
                    onSave: { placeId, actTitles, _ in
                        appState.addCourseStep(courseId: courseId, placeId: placeId, actTitles: actTitles)
                    }
                )
                .environmentObject(appState)
            }
        }
        .sheet(item: $editingStep) { step in
            NavigationStack {
                CourseStepEditorView(
                    title: "Stepを編集",
                    initialPlaceId: step.placeId ?? appState.places.first(where: { $0.category == step.placeCategory })?.id,
                    initialActTitles: step.tasks.map(\.title),
                    initialIsEnabled: step.isEnabled,
                    saveTitle: "保存",
                    onSave: { placeId, actTitles, isEnabled in
                        appState.updateCourseStep(ruleId: step.id, placeId: placeId, actTitles: actTitles)
                        appState.setCourseStepEnabled(step.id, isEnabled: isEnabled)
                    },
                    onDelete: {
                        appState.deleteCourseStep(ruleId: step.id)
                    }
                )
                .environmentObject(appState)
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: {
                appState.course(for: courseId)?.name ?? ""
            },
            set: { name in
                appState.setCourseName(courseId, name: name)
            }
        )
    }

    private var descriptionBinding: Binding<String> {
        Binding(
            get: {
                appState.course(for: courseId)?.description ?? ""
            },
            set: { description in
                appState.setCourseDescription(courseId, description: description)
            }
        )
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: {
                appState.course(for: courseId)?.isEnabled ?? false
            },
            set: { isEnabled in
                appState.setCourseEnabled(courseId, isEnabled: isEnabled)
            }
        )
    }

    private var weekdayTypeBinding: Binding<WeekdayType> {
        Binding(
            get: {
                appState.course(for: courseId)?.weekdayType ?? .any
            },
            set: { weekdayType in
                appState.setCourseWeekdayType(courseId, weekdayType: weekdayType)
            }
        )
    }

    private var timeBlockBinding: Binding<TimeBlock> {
        Binding(
            get: {
                appState.course(for: courseId)?.timeBlock ?? .any
            },
            set: { timeBlock in
                appState.setCourseTimeBlock(courseId, timeBlock: timeBlock)
            }
        )
    }

}

private struct CourseStepRowView: View {
    @EnvironmentObject private var appState: AppState

    let step: HabitRule

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: appState.rulePlaceSystemImage(step))
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(appState.rulePlaceDisplayName(step))
                    .font(.subheadline.weight(.semibold))

                Text(appState.ruleActTitle(step))
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
}

private struct CourseStepEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let title: String
    let saveTitle: String
    let onSave: (UUID, [String], Bool) -> Void
    let onDelete: (() -> Void)?

    @State private var selectedPlaceId: UUID?
    @State private var actTitles: [String]
    @State private var newActTitle: String
    @State private var isEnabled: Bool
    @State private var isDeleteConfirmationPresented = false

    init(
        title: String,
        initialPlaceId: UUID?,
        initialActTitles: [String],
        initialIsEnabled: Bool,
        saveTitle: String,
        onSave: @escaping (UUID, [String], Bool) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.onSave = onSave
        self.onDelete = onDelete
        _selectedPlaceId = State(initialValue: initialPlaceId)
        _actTitles = State(initialValue: initialActTitles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        _newActTitle = State(initialValue: "")
        _isEnabled = State(initialValue: initialIsEnabled)
    }

    private var normalizedActTitles: [String] {
        var seenTitles: Set<String> = []
        var result: [String] = []
        for title in actTitles.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) {
            guard !title.isEmpty, !seenTitles.contains(title) else { continue }
            seenTitles.insert(title)
            result.append(title)
        }
        return result
    }

    private var normalizedNewActTitle: String {
        newActTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        selectedPlaceId != nil && !normalizedActTitles.isEmpty
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
                Text("Stepには複数のActを入れられます。例: 自宅Stepにクレアチンとシダキュアを入れます。")
            }

            Section("状態") {
                Toggle("このStepを使う", isOn: $isEnabled)
            }

            Section {
                EditorActionBar(
                    canSave: canSave,
                    onSave: {
                        guard let selectedPlaceId else { return }
                        onSave(selectedPlaceId, normalizedActTitles, isEnabled)
                        dismiss()
                    },
                    onCancel: {
                        dismiss()
                    },
                    onDelete: onDelete == nil ? nil : {
                        isDeleteConfirmationPresented = true
                    }
                )
            }
        }
        .themedScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Stepを削除しますか？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                onDelete?()
                dismiss()
            }

            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(normalizedActTitles.joined(separator: " / "))
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

struct CourseCreatorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var purpose = ""
    @State private var courseDescription = ""
    @State private var stepDrafts: [CourseStepDraft] = [
        CourseStepDraft()
    ]

    private var normalizedPurpose: String {
        purpose.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedDescription: String {
        courseDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedSteps: [CourseStepDraft] {
        stepDrafts.compactMap { step in
            let title = step.actTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard step.placeId != nil, !title.isEmpty else { return nil }
            return CourseStepDraft(id: step.id, placeId: step.placeId, actTitle: title)
        }
    }

    private var canSave: Bool {
        !normalizedPurpose.isEmpty && !normalizedSteps.isEmpty
    }

    var body: some View {
        Form {
            Section {
                CourseCreationFlowView()
            }

            Section {
                TextField("例: 忘れ物を減らす", text: $purpose, axis: .vertical)
                    .lineLimit(1...2)

                TextField("説明。未入力なら目的から自動作成します", text: $courseDescription, axis: .vertical)
                    .lineLimit(1...3)
            } header: {
                Text("1. 目的")
            } footer: {
                Text("目的はCourse名になります。短い言葉にするとCourse一覧で見やすくなります。")
            }

            Section {
                ForEach(stepDrafts) { step in
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Place", selection: stepPlaceBinding(for: step.id)) {
                            Text("選択")
                                .tag(UUID?.none)

                            ForEach(appState.places) { place in
                                Label(place.name, systemImage: place.category.systemImage)
                                    .tag(Optional(place.id))
                            }
                        }

                        if !appState.actTemplates.isEmpty {
                            Picker("既存Act", selection: stepActBinding(for: step.id)) {
                                Text("選択")
                                    .tag("")

                                ForEach(appState.actTemplates) { act in
                                    Text(act.title)
                                        .tag(act.title)
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            TextField("例: クレアチンを飲む", text: stepActBinding(for: step.id), axis: .vertical)
                                .lineLimit(1...3)

                            if stepDrafts.count > 1 {
                                Button(role: .destructive) {
                                    removeStep(step.id)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Stepを削除")
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    stepDrafts.append(CourseStepDraft(placeId: appState.places.first?.id))
                } label: {
                    Label("Stepを追加", systemImage: "plus.circle")
                }
            } header: {
                Text("2. Steps")
            } footer: {
                Text("StepはPlaceとActの組み合わせです。自宅には接種系、店やレストランには外食抑制、のように分けて設定します。")
            }

            Section {
                GuideInfoCard(
                    systemImage: "checklist",
                    title: "通知時に自動作成",
                    detail: "保存後、StepのPlaceに入ると、そのStepのActだけがStepsとして記録されます。"
                )
            } header: {
                Text("3. 保存後")
            }
        }
        .themedScreenBackground()
        .navigationTitle("コース作成")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if stepDrafts.count == 1, stepDrafts[0].placeId == nil {
                stepDrafts[0].placeId = appState.places.first?.id
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    appState.createCourse(
                        purpose: normalizedPurpose,
                        description: normalizedDescription,
                        steps: normalizedSteps
                    )
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
    }

    private func stepPlaceBinding(for stepId: UUID) -> Binding<UUID?> {
        Binding(
            get: {
                stepDrafts.first(where: { $0.id == stepId })?.placeId
            },
            set: { value in
                guard let index = stepDrafts.firstIndex(where: { $0.id == stepId }) else { return }
                stepDrafts[index].placeId = value
            }
        )
    }

    private func stepActBinding(for stepId: UUID) -> Binding<String> {
        Binding(
            get: {
                stepDrafts.first(where: { $0.id == stepId })?.actTitle ?? ""
            },
            set: { value in
                guard let index = stepDrafts.firstIndex(where: { $0.id == stepId }) else { return }
                stepDrafts[index].actTitle = value
            }
        )
    }

    private func removeStep(_ stepId: UUID) {
        stepDrafts.removeAll { $0.id == stepId }
    }
}

private struct CourseCreationFlowView: View {
    var body: some View {
        VStack(spacing: 10) {
            GuideStepCard(
                number: 1,
                systemImage: "target",
                title: "目的",
                action: "入力",
                detail: "Course全体の方向性。"
            )

            FlowArrow()

            GuideStepCard(
                number: 2,
                systemImage: "mappin.and.ellipse",
                title: "Place",
                action: "選択",
                detail: "通知のきっかけになる場所カテゴリ。"
            )

            FlowArrow()

            GuideStepCard(
                number: 3,
                systemImage: "list.bullet.rectangle",
                title: "Act",
                action: "作成",
                detail: "場所に着いたときに出すAct。"
            )

            FlowArrow()

            GuideStepCard(
                number: 4,
                systemImage: "checklist",
                title: "Steps",
                action: "記録",
                detail: "通知された1回分の実行記録。"
            )

            GuideInfoCard(
                systemImage: "point.3.connected.trianglepath.dotted",
                title: "関係",
                detail: "目的はCourseの方向性、Placeは発火条件、Actはやることの型、Stepsは実際に通知された1回分の記録です。"
            )
        }
    }
}

private struct GuideStepCard: View {
    @EnvironmentObject private var appState: AppState

    let number: Int
    let systemImage: String
    let title: String
    let action: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor)
                    .clipShape(Circle())

                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)

                Text(title)
                    .font(.headline)

                Spacer()

                Text(action)
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.10))
                    .clipShape(Capsule())
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appState.appTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(appState.appTheme.elementBorderColor, lineWidth: appState.appTheme.elementBorderWidth)
        }
        .shadow(color: .black.opacity(appState.appTheme == .gray ? 0.12 : 0), radius: 5, x: 0, y: 1)
    }
}

private struct FlowArrow: View {
    var body: some View {
        Image(systemName: "chevron.down")
            .font(.caption.bold())
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

private struct GuideInfoCard: View {
    @EnvironmentObject private var appState: AppState

    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appState.appTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(appState.appTheme.elementBorderColor, lineWidth: appState.appTheme.elementBorderWidth)
        }
    }
}
