import Foundation

enum AppTab: Hashable {
    case home
    case place
    case act
    case steps
    case log
}

@MainActor
final class AppState: ObservableObject {
    struct MapSelection: Identifiable {
        let placeId: UUID

        var id: UUID { placeId }
    }

    private struct PendingNotificationResponse {
        let logId: UUID
        let placeId: UUID?
        let action: UserAction
    }

    private struct NotificationPayload {
        let title: String
        let subtitle: String
        let message: String
        let courseId: UUID?
        let actionGuide: ActionGuide
        let tasks: [RuleTask]
    }

    @Published var places: [Place] = [] {
        didSet {
            savePlaces()
            syncRegionMonitoringIfReady()
        }
    }

    @Published var courses: [HabitCourse] = [] {
        didSet {
            saveCourses()
        }
    }

    @Published var rules: [HabitRule] = [] {
        didSet {
            saveRules()
        }
    }

    @Published var acts: [RuleTask] = [] {
        didSet {
            saveActs()
        }
    }

    @Published var logs: [TriggerLog] = [] {
        didSet {
            saveLogs()
        }
    }

    @Published var mapSelection: MapSelection?
    @Published var selectedTab: AppTab = .home
    @Published var focusedLogId: UUID?
    @Published var focusedStepId: UUID?
    @Published var appTheme: AppTheme = .plain {
        didSet {
            saveAppTheme()
        }
    }

    let notificationService = NotificationService()
    let locationService = LocationService()

    private let store = LocalStore()
    private var hasBootstrapped = false
    private let duplicateNotificationWindow: TimeInterval = 120
    private var pendingNotificationResponse: PendingNotificationResponse?

    init() {
        notificationService.onResponse = { [weak self] logId, placeId, action in
            Task { @MainActor in
                self?.handleNotificationResponse(logId: logId, placeId: placeId, action: action)
            }
        }

        locationService.onRegionEvent = { [weak self] placeId, triggerType in
            Task { @MainActor in
                self?.handleRegionEvent(placeId: placeId, triggerType: triggerType)
            }
        }

        locationService.onAuthorizationChanged = { [weak self] in
            Task { @MainActor in
                self?.syncRegionMonitoringIfReady()
            }
        }
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }

        appTheme = store.load(AppTheme.self, from: "app_theme.json") ?? .plain
        places = store.load([Place].self, from: "places.json") ?? PresetData.places
        courses = normalizeCourses(store.load([HabitCourse].self, from: "courses.json") ?? PresetData.courses)
        let loadedRules = store.load([HabitRule].self, from: "rules.json") ?? PresetData.rules
        rules = normalizeRules(loadedRules)
        acts = normalizeActCatalog(store.load([RuleTask].self, from: "acts.json") ?? rules.flatMap(\.tasks))
        logs = normalizeLogs(store.load([TriggerLog].self, from: "logs.json") ?? [])

        hasBootstrapped = true
        notificationService.refreshAuthorizationStatus()
        locationService.refreshAuthorizationStatus()
        syncRegionMonitoringIfReady()
        applyPendingNotificationResponseIfNeeded()

        if locationService.authorizationStatus.allowsRegionMonitoring {
            requestCurrentLocation()
        }
    }

    func requestNotificationPermission() {
        notificationService.requestAuthorization()
    }

    func requestLocationPermission() {
        locationService.requestAlwaysAuthorization()
    }

    func requestForegroundLocationPermission() {
        locationService.requestWhenInUseAuthorization()
    }

    func requestBackgroundLocationPermission() {
        locationService.requestAlwaysAuthorization()
    }

    func requestCurrentLocation() {
        locationService.requestCurrentLocation()
    }

    func addPlace(_ place: Place) {
        places.append(place)
    }

    func updatePlace(_ place: Place) {
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[index] = place
    }

    func deletePlaces(at offsets: IndexSet) {
        let ids = offsets.map { places[$0].id }
        places.removeAll { ids.contains($0.id) }
    }

    func setPlaceEnabled(_ placeId: UUID, isEnabled: Bool) {
        guard let index = places.firstIndex(where: { $0.id == placeId }) else { return }
        places[index].isEnabled = isEnabled
    }

    func setCourseEnabled(_ courseId: UUID, isEnabled: Bool) {
        guard let index = courses.firstIndex(where: { $0.id == courseId }) else { return }
        courses[index].isEnabled = isEnabled
    }

    func setCourseTimeBlock(_ courseId: UUID, timeBlock: TimeBlock) {
        guard let index = courses.firstIndex(where: { $0.id == courseId }) else { return }
        courses[index].timeBlock = timeBlock
    }

    func setCourseWeekdayType(_ courseId: UUID, weekdayType: WeekdayType) {
        guard let index = courses.firstIndex(where: { $0.id == courseId }) else { return }
        courses[index].weekdayType = weekdayType
    }

    func setCourseName(_ courseId: UUID, name: String) {
        guard let index = courses.firstIndex(where: { $0.id == courseId }) else { return }
        courses[index].name = name
    }

    func setCourseDescription(_ courseId: UUID, description: String) {
        guard let index = courses.firstIndex(where: { $0.id == courseId }) else { return }
        courses[index].description = description
    }

    func setCourseTargetCategories(_ courseId: UUID, categories: [PlaceCategory]) {
        let normalizedCategories = orderedCategories(from: categories)
        guard !normalizedCategories.isEmpty,
              let index = courses.firstIndex(where: { $0.id == courseId })
        else {
            return
        }

        courses[index].targetCategories = normalizedCategories
    }

    func createCourse(purpose: String, description: String, steps: [CourseStepDraft]) {
        let normalizedPurpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSteps = normalizedCourseStepDrafts(steps)
        let normalizedCategories = orderedCategories(
            from: normalizedSteps.compactMap { step in
                guard let placeId = step.placeId else { return nil }
                return place(for: placeId)?.category
            }
        )

        guard !normalizedPurpose.isEmpty,
              !normalizedCategories.isEmpty,
              !normalizedSteps.isEmpty
        else {
            return
        }

        let course = HabitCourse(
            name: normalizedPurpose,
            description: normalizedDescription.isEmpty ? "目的: \(normalizedPurpose)" : normalizedDescription,
            isEnabled: true,
            targetCategories: normalizedCategories
        )

        courses.append(course)

        for step in normalizedSteps {
            guard let placeId = step.placeId else { continue }
            addCourseStep(courseId: course.id, placeId: placeId, actTitle: step.actTitle)
        }
    }

    func setAppTheme(_ theme: AppTheme) {
        appTheme = theme
    }

    func course(for courseId: UUID) -> HabitCourse? {
        courses.first { $0.id == courseId }
    }

    func courseSteps(for courseId: UUID) -> [HabitRule] {
        rules
            .filter { $0.courseId == courseId && $0.triggerType == .enter }
            .sorted { left, right in
                let leftPlace = rulePlaceDisplayName(left)
                let rightPlace = rulePlaceDisplayName(right)

                if leftPlace == rightPlace {
                    return ruleActTitle(left).localizedCompare(ruleActTitle(right)) == .orderedAscending
                }

                return leftPlace.localizedCompare(rightPlace) == .orderedAscending
            }
    }

    var defaultStepCourseId: UUID? {
        courses.first(where: \.isEnabled)?.id ?? courses.first?.id
    }

    func registeredSteps() -> [HabitRule] {
        rules
            .filter { $0.triggerType == .enter }
            .sorted { left, right in
                let leftPlace = rulePlaceDisplayName(left)
                let rightPlace = rulePlaceDisplayName(right)

                if leftPlace == rightPlace {
                    return ruleActTitle(left).localizedCompare(ruleActTitle(right)) == .orderedAscending
                }

                return leftPlace.localizedCompare(rightPlace) == .orderedAscending
            }
    }

    func addStep(placeId: UUID, actTitles: [String]) {
        guard let courseId = defaultStepCourseId else { return }
        addCourseStep(courseId: courseId, placeId: placeId, actTitles: actTitles)
    }

    func addCourseStep(courseId: UUID, placeId: UUID, actTitle: String) {
        addCourseStep(courseId: courseId, placeId: placeId, actTitles: [actTitle])
    }

    func addCourseStep(courseId: UUID, placeId: UUID, actTitles: [String]) {
        guard let place = place(for: placeId) else { return }
        addCourseStep(courseId: courseId, place: place, actTitles: actTitles)
    }

    func updateCourseStep(ruleId: UUID, placeId: UUID, actTitle: String) {
        guard let rule = rule(for: ruleId) else { return }
        updateCourseStep(ruleId: ruleId, courseId: rule.courseId, placeId: placeId, actTitles: [actTitle])
    }

    func updateCourseStep(ruleId: UUID, placeId: UUID, actTitles: [String]) {
        guard let rule = rule(for: ruleId) else { return }
        updateCourseStep(ruleId: ruleId, courseId: rule.courseId, placeId: placeId, actTitles: actTitles)
    }

    func updateCourseStep(ruleId: UUID, courseId: UUID, placeId: UUID, actTitles: [String]) {
        guard let place = place(for: placeId),
              let index = rules.firstIndex(where: { $0.id == ruleId }),
              courses.contains(where: { $0.id == courseId })
        else {
            return
        }

        let previousCourseId = rules[index].courseId
        let normalizedTitles = normalizedActTitles(actTitles)
        guard !normalizedTitles.isEmpty else { return }
        let normalizedTasks = normalizedTitles.map { RuleTask(title: $0) }

        rules[index].courseId = courseId
        rules[index].placeId = place.id
        rules[index].placeCategory = place.category
        rules[index].message = normalizedTitles.first ?? ""
        rules[index].tasks = normalizedTasks
        rules[index].isEnabled = true

        for title in normalizedTitles where !acts.contains(where: { normalizedActTitle($0.title) == title }) {
            acts.append(RuleTask(title: title))
        }

        syncCourseTargetCategories(for: previousCourseId)
        syncCourseTargetCategories(for: courseId)
    }

    func deleteCourseStep(ruleId: UUID) {
        guard let rule = rule(for: ruleId) else { return }
        rules.removeAll { $0.id == ruleId }
        syncCourseTargetCategories(for: rule.courseId)
    }

    func setCourseStepEnabled(_ ruleId: UUID, isEnabled: Bool) {
        guard let index = rules.firstIndex(where: { $0.id == ruleId }) else { return }
        rules[index].isEnabled = isEnabled
    }

    func rulePlaceDisplayName(_ rule: HabitRule) -> String {
        if let placeId = rule.placeId,
           let place = place(for: placeId) {
            return place.name
        }

        return rule.placeCategory.displayName
    }

    func rulePlaceSystemImage(_ rule: HabitRule) -> String {
        if let placeId = rule.placeId,
           let place = place(for: placeId) {
            return place.category.systemImage
        }

        return rule.placeCategory.systemImage
    }

    func ruleActTitle(_ rule: HabitRule) -> String {
        let titles = normalizedRuleTasks(rule.tasks, fallback: rule.message).map(\.title)
        if titles.count > 1 {
            return "\(titles[0]) ほか\(titles.count - 1)件"
        }
        return titles.first ?? rule.message
    }

    var actTemplates: [ActTemplate] {
        let titles = acts
            .map { normalizedActTitle($0.title) }
            .filter { !$0.isEmpty }

        let counts = Dictionary(grouping: titles, by: { $0 })
            .mapValues(\.count)

        return counts.keys
            .sorted { $0.localizedCompare($1) == .orderedAscending }
            .map { ActTemplate(title: $0, usageCount: counts[$0] ?? 0) }
    }

    func addAct(title: String) {
        let normalizedTitle = normalizedActTitle(title)
        guard !normalizedTitle.isEmpty,
              !acts.contains(where: { normalizedActTitle($0.title) == normalizedTitle })
        else { return }

        acts.append(RuleTask(title: normalizedTitle))
    }

    func updateAct(matching oldTitle: String, to newTitle: String) {
        let normalizedOldTitle = normalizedActTitle(oldTitle)
        let normalizedNewTitle = normalizedActTitle(newTitle)

        guard !normalizedOldTitle.isEmpty,
              !normalizedNewTitle.isEmpty
        else {
            return
        }

        for index in acts.indices where normalizedActTitle(acts[index].title) == normalizedOldTitle {
            acts[index].title = normalizedNewTitle
        }

        for index in rules.indices {
            var updatedTasks = rules[index].tasks
            var didUpdate = false

            for taskIndex in updatedTasks.indices where normalizedActTitle(updatedTasks[taskIndex].title) == normalizedOldTitle {
                updatedTasks[taskIndex].title = normalizedNewTitle
                didUpdate = true
            }

            guard didUpdate else { continue }

            rules[index].tasks = deduplicatedRuleTasks(updatedTasks)

            if normalizedActTitle(rules[index].message) == normalizedOldTitle || rules[index].message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rules[index].message = rules[index].tasks.first?.title ?? normalizedNewTitle
            }
        }

        for index in courses.indices {
            courses[index].disabledActTitles = normalizedActTitles(
                courses[index].disabledActTitles.map {
                    normalizedActTitle($0) == normalizedOldTitle ? normalizedNewTitle : $0
                }
            )
        }
    }

    func deleteAct(matching title: String) {
        let normalizedTitle = normalizedActTitle(title)
        guard !normalizedTitle.isEmpty else { return }

        acts.removeAll { normalizedActTitle($0.title) == normalizedTitle }

        for index in rules.indices {
            let remainingTasks = rules[index].tasks.filter {
                normalizedActTitle($0.title) != normalizedTitle
            }

            guard remainingTasks.count != rules[index].tasks.count else { continue }

            rules[index].tasks = remainingTasks

            if let firstTask = remainingTasks.first {
                rules[index].message = firstTask.title
            } else {
                rules[index].message = ""
                rules[index].isEnabled = false
            }
        }

        for index in courses.indices {
            courses[index].disabledActTitles = normalizedActTitles(
                courses[index].disabledActTitles.filter {
                    normalizedActTitle($0) != normalizedTitle
                }
            )
        }
    }

    func updateRuleMessage(ruleId: UUID, message: String) {
        guard let index = rules.firstIndex(where: { $0.id == ruleId }) else { return }
        rules[index].message = message
    }

    func updateRuleTasks(ruleId: UUID, tasks: [RuleTask]) {
        guard let index = rules.firstIndex(where: { $0.id == ruleId }) else { return }
        let normalizedTasks = normalizedRuleTasks(tasks, fallback: rules[index].message)
        rules[index].tasks = normalizedTasks
        rules[index].message = normalizedTasks.first?.title ?? rules[index].message
    }

    func rule(for ruleId: UUID) -> HabitRule? {
        rules.first { $0.id == ruleId }
    }

    func presetRuleMessage(for ruleId: UUID) -> String? {
        PresetData.rules.first { $0.id == ruleId }?.message
    }

    func presetRuleTasks(for ruleId: UUID) -> [RuleTask]? {
        PresetData.tasks(for: ruleId)
    }

    func testEnterTrigger(for place: Place) {
        handleRegionEvent(placeId: place.id, triggerType: .enter, suppressDuplicates: false)
    }

    func placeName(for placeId: UUID) -> String {
        places.first(where: { $0.id == placeId })?.name ?? "削除済みの場所"
    }

    func place(for placeId: UUID) -> Place? {
        places.first { $0.id == placeId }
    }

    func log(for logId: UUID) -> TriggerLog? {
        logs.first { $0.id == logId }
    }

    func clearLogs() {
        logs = []
        focusedLogId = nil
    }

    func openStep(_ ruleId: UUID) {
        focusedStepId = ruleId
        focusedLogId = nil
        selectedTab = .steps
    }

    func showMap(for placeId: UUID) {
        guard place(for: placeId) != nil else { return }
        requestCurrentLocation()
        mapSelection = MapSelection(placeId: placeId)
    }

    func openSteps(for logId: UUID) {
        focusedLogId = logId
        focusedStepId = nil
        selectedTab = .log
    }

    func focusLog(_ logId: UUID) {
        focusedLogId = logId
    }

    func reopenLog(_ logId: UUID) {
        guard let index = logs.firstIndex(where: { $0.id == logId }) else { return }
        logs[index].userAction = .opened
        logs[index].snoozedUntil = nil
        logs[index].tasks = logs[index].tasks.map { task in
            var editableTask = task
            editableTask.isCompleted = false
            return editableTask
        }
        openSteps(for: logId)
    }

    func actionGuide(for log: TriggerLog) -> ActionGuide {
        if let actionGuide = log.actionGuide {
            return actionGuide
        }
        return fallbackGuide(for: log)
    }

    func markDidAction(logId: UUID) {
        updateLogAction(logId: logId, action: .didAction)
        openSteps(for: logId)
    }

    func markAvoidedAction(logId: UUID) {
        updateLogAction(logId: logId, action: .avoidedAction)
        openSteps(for: logId)
    }

    func completeStepTask(logId: UUID, taskId: UUID) {
        guard let index = logs.firstIndex(where: { $0.id == logId }) else { return }
        ensureLogTasks(at: index)
        guard let taskIndex = logs[index].tasks.firstIndex(where: { $0.id == taskId }) else { return }
        logs[index].tasks[taskIndex].isCompleted = true
        markStepCompleteIfReady(at: index)
        openSteps(for: logId)
    }

    func deleteStepTask(logId: UUID, taskId: UUID) {
        guard let index = logs.firstIndex(where: { $0.id == logId }) else { return }
        ensureLogTasks(at: index)
        logs[index].tasks.removeAll { $0.id == taskId }
        markStepCompleteIfReady(at: index)
        openSteps(for: logId)
    }

    func snoozeLog(logId: UUID, until date: Date) {
        guard let index = logs.firstIndex(where: { $0.id == logId }) else { return }
        logs[index].userAction = .snoozed
        logs[index].snoozedUntil = date

        let log = logs[index]
        guard let place = place(for: log.placeId) else { return }
        notificationService.deliver(
            title: notificationTitle(for: place),
            subtitle: courseName(for: log.courseId),
            body: log.message,
            logId: log.id,
            placeId: log.placeId,
            courseId: log.courseId,
            at: date
        )
    }

    var pendingActionCount: Int {
        logs.filter { !$0.userAction.isResolved }.count
    }

    func courseName(for courseId: UUID?) -> String {
        guard let courseId else { return "共通通知" }
        return courses.first(where: { $0.id == courseId })?.name ?? "削除済みのコース"
    }

    func refreshMonitoringState() {
        locationService.refreshAuthorizationStatus()
        syncRegionMonitoringIfReady()

        if locationService.authorizationStatus.allowsRegionMonitoring {
            requestCurrentLocation()
        }
    }

    private func handleRegionEvent(placeId: UUID, triggerType: TriggerType, suppressDuplicates: Bool = true) {
        guard let place = places.first(where: { $0.id == placeId && $0.isEnabled }) else { return }
        let eventDate = Date()

        let matches = RuleEngine.matchingRules(
            for: place,
            triggerType: triggerType,
            date: eventDate,
            courses: courses,
            rules: rules
        )

        guard let payload = notificationPayload(for: place, matches: matches) else {
            return
        }

        if suppressDuplicates && isDuplicateEvent(for: place.id, triggerType: triggerType) {
            return
        }

        let log = TriggerLog(
            placeId: place.id,
            courseId: payload.courseId,
            triggerType: triggerType,
            message: payload.message,
            actionGuide: payload.actionGuide,
            tasks: payload.tasks.map(StepTask.init(ruleTask:))
        )

        logs.insert(log, at: 0)
        logs = Array(logs.prefix(200))

        notificationService.deliver(
            title: payload.title,
            subtitle: payload.subtitle,
            body: payload.message,
            logId: log.id,
            placeId: place.id,
            courseId: payload.courseId
        )
    }

    private func notificationPayload(for place: Place, matches: [RuleMatch]) -> NotificationPayload? {
        let matchTasks = matches.compactMap { match -> (match: RuleMatch, tasks: [RuleTask])? in
            let tasks = enabledRuleTasks(match.rule, course: match.course)
            guard !tasks.isEmpty else { return nil }
            return (match, tasks)
        }

        guard let firstMatch = matchTasks.first else { return nil }

        let tasks = deduplicatedRuleTasks(matchTasks.flatMap { $0.tasks })
        guard !tasks.isEmpty else { return nil }

        let courseNames = normalizedActTitles(matchTasks.map { $0.match.course.name })
        let courseIds = normalizedCourseIds(matchTasks.map { $0.match.course.id })
        let courseId = courseIds.count == 1 ? courseIds[0] : nil
        let actionGuide = ActionGuide(
            doText: tasks[0].title,
            avoidText: guide(for: place, match: firstMatch.match).avoidText
        )

        return NotificationPayload(
            title: notificationTitle(for: place),
            subtitle: courseNames.joined(separator: " / "),
            message: notificationMessage(for: tasks),
            courseId: courseId,
            actionGuide: actionGuide,
            tasks: tasks
        )
    }

    private func isDuplicateEvent(for placeId: UUID, triggerType: TriggerType) -> Bool {
        guard let latestLog = logs.first(where: { $0.placeId == placeId && $0.triggerType == triggerType }) else {
            return false
        }

        return Date().timeIntervalSince(latestLog.triggeredAt) < duplicateNotificationWindow
    }

    private func hasEnabledAct(for place: Place, triggerType: TriggerType, date: Date) -> Bool {
        let enabledCourses = courses.filter {
            $0.isEnabled &&
            $0.timeBlock.matches(date: date) &&
            $0.weekdayType.matches(date: date)
        }

        return rules.contains { rule in
            guard rule.isEnabled,
                  rule.triggerType == triggerType,
                  rule.timeBlock.matches(date: date),
                  rule.weekdayType.matches(date: date),
                  !rule.tasks.isEmpty,
                  enabledCourses.contains(where: { $0.id == rule.courseId })
            else {
                return false
            }

            return ruleMatches(place: place, rule: rule) &&
                !normalizedRuleTasks(rule.tasks, fallback: rule.message).isEmpty
        }
    }

    private func notificationTitle(for place: Place) -> String {
        "\(place.category.notificationEmoji) \(place.name)"
    }

    private func guide(for place: Place, match: RuleMatch) -> ActionGuide {
        if let firstTask = normalizedRuleTasks(match.rule.tasks, fallback: match.message).first {
            let avoidText = PresetData.guide(for: match.rule.id)?.avoidText ?? fallbackGuide(for: place).avoidText
            return ActionGuide(doText: firstTask.title, avoidText: avoidText)
        }

        return PresetData.guide(for: match.rule.id) ?? fallbackGuide(for: place)
    }

    private func fallbackGuide(for log: TriggerLog) -> ActionGuide {
        guard let place = place(for: log.placeId) else {
            return ActionGuide(
                doText: log.message.replacingOccurrences(of: "。", with: ""),
                avoidText: "流れで先送りにする"
            )
        }
        return fallbackGuide(for: place)
    }

    private func fallbackGuide(for place: Place) -> ActionGuide {
        switch place.category {
        case .home:
            return ActionGuide(
                doText: "帰宅後に、できそうなことを1つだけ始めてみる",
                avoidText: "ゆっくり過ごす前に一度だけ思い出す"
            )
        case .station:
            return ActionGuide(
                doText: "移動時間の最初の5分だけ使ってみる",
                avoidText: "あとで思い出せるように少しだけ整える"
            )
        case .office:
            return ActionGuide(
                doText: "最初の5分だけ大事な作業に触れてみる",
                avoidText: "始めやすい順番を一度だけ選ぶ"
            )
        case .gym:
            return ActionGuide(
                doText: "5分だけ体を動かして様子を見る",
                avoidText: "迷ったら軽い動きから始める"
            )
        case .library:
            return ActionGuide(
                doText: "10分だけ静かな時間を作ってみる",
                avoidText: "気になることはあとで見る"
            )
        case .barArea:
            return ActionGuide(
                doText: "今日はそのまま帰る選択を思い出してみる",
                avoidText: "流れに乗る前に一度だけ立ち止まる"
            )
        case .convenienceStore:
            return ActionGuide(
                doText: "必要なものだけ軽く確認してみる",
                avoidText: "ついで買いは明日でもいいか考える"
            )
        case .other:
            return ActionGuide(
                doText: "1分だけでもできることを始めてみる",
                avoidText: "あとで見返せるように小さく残す"
            )
        }
    }

    private func handleNotificationResponse(logId: UUID, placeId: UUID?, action: UserAction) {
        guard hasBootstrapped else {
            pendingNotificationResponse = PendingNotificationResponse(logId: logId, placeId: placeId, action: action)
            return
        }
        applyNotificationResponse(logId: logId, placeId: placeId, action: action)
    }

    private func applyPendingNotificationResponseIfNeeded() {
        guard let pendingNotificationResponse else { return }
        self.pendingNotificationResponse = nil
        applyNotificationResponse(
            logId: pendingNotificationResponse.logId,
            placeId: pendingNotificationResponse.placeId,
            action: pendingNotificationResponse.action
        )
    }

    private func applyNotificationResponse(logId: UUID, placeId: UUID?, action: UserAction) {
        updateLogAction(logId: logId, action: action)

        switch action {
        case .opened:
            openSteps(for: logId)
        case .mapOpened:
            if let placeId {
                showMap(for: placeId)
            }
        case .ignored, .completed, .didAction, .avoidedAction, .dismissed, .snoozed:
            break
        }
    }

    private func updateLogAction(logId: UUID, action: UserAction) {
        guard let index = logs.firstIndex(where: { $0.id == logId }) else { return }
        logs[index].userAction = mergeUserAction(current: logs[index].userAction, incoming: action)
    }

    private func normalizeCourses(_ courses: [HabitCourse]) -> [HabitCourse] {
        let presetCourse = PresetData.todoListCourse
        var normalizedCourses = courses.filter { !PresetData.retiredPresetCourseIds.contains($0.id) }

        if let presetIndex = normalizedCourses.firstIndex(where: { $0.id == presetCourse.id }) {
            var normalizedCourse = normalizedCourses[presetIndex]

            if normalizedCourse.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                normalizedCourse.name = presetCourse.name
            }

            if normalizedCourse.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                normalizedCourse.description = presetCourse.description
            }

            if normalizedCourse.targetCategories.isEmpty {
                normalizedCourse.targetCategories = presetCourse.targetCategories
            }

            normalizedCourse.disabledActTitles = normalizedActTitles(normalizedCourse.disabledActTitles)
            normalizedCourses[presetIndex] = normalizedCourse
        } else {
            normalizedCourses.insert(presetCourse, at: 0)
        }

        return normalizedCourses
    }

    private func normalizeRules(_ rules: [HabitRule]) -> [HabitRule] {
        let activeCourseIds = Set(courses.map(\.id))
        let activePlaceIds = Set(places.map(\.id))
        var mergedRules = rules.filter {
            activeCourseIds.contains($0.courseId) &&
            !PresetData.retiredPresetRuleIds.contains($0.id) &&
            $0.placeId.map(activePlaceIds.contains) == true
        }

        for presetRule in PresetData.rules where !mergedRules.contains(where: { $0.id == presetRule.id }) {
            mergedRules.append(presetRule)
        }

        return mergedRules.compactMap { rule in
            let normalizedMessage = normalizedMessage(rule.message)
            let normalizedTasks = normalizedRuleTasks(rule.tasks, fallback: normalizedMessage)
            guard !normalizedTasks.isEmpty else { return nil }

            var stepRule = rule
            stepRule.tasks = normalizedTasks
            stepRule.message = normalizedTasks.first?.title ?? normalizedMessage
            return stepRule
        }
    }

    private func normalizeActCatalog(_ acts: [RuleTask]) -> [RuleTask] {
        deduplicatedRuleTasks(acts)
    }

    private func normalizedCourseStepDrafts(_ steps: [CourseStepDraft]) -> [CourseStepDraft] {
        var seenKeys: Set<String> = []
        var result: [CourseStepDraft] = []

        for step in steps {
            let title = normalizedActTitle(step.actTitle)
            guard let placeId = step.placeId, !title.isEmpty else { continue }

            let key = "\(placeId.uuidString)-\(title)"
            guard !seenKeys.contains(key) else { continue }

            seenKeys.insert(key)
            result.append(CourseStepDraft(id: step.id, placeId: placeId, actTitle: title))
        }

        return result
    }

    private func normalizeLogs(_ logs: [TriggerLog]) -> [TriggerLog] {
        logs.map { log in
            var normalizedLog = log

            if normalizedLog.tasks.isEmpty {
                normalizedLog.tasks = [fallbackStepTask(for: normalizedLog)]
            }

            return normalizedLog
        }
    }

    private func normalizedRuleTasks(_ tasks: [RuleTask], fallback: String) -> [RuleTask] {
        let normalizedTasks = tasks.compactMap { task -> RuleTask? in
            let title = normalizedActTitle(task.title)
            guard !title.isEmpty else { return nil }
            return RuleTask(id: task.id, title: title)
        }

        if normalizedTasks.isEmpty {
            let fallbackTitle = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fallbackTitle.isEmpty else { return [] }
            return [RuleTask(title: fallbackTitle)]
        }

        return normalizedTasks
    }

    private func normalizedActTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedActTitles(_ titles: [String]) -> [String] {
        var seenTitles: Set<String> = []
        var result: [String] = []

        for title in titles.map(normalizedActTitle) {
            guard !title.isEmpty, !seenTitles.contains(title) else { continue }
            seenTitles.insert(title)
            result.append(title)
        }

        return result
    }

    private func normalizedCourseIds(_ courseIds: [UUID]) -> [UUID] {
        var seenIds: Set<UUID> = []
        var result: [UUID] = []

        for courseId in courseIds {
            guard !seenIds.contains(courseId) else { continue }
            seenIds.insert(courseId)
            result.append(courseId)
        }

        return result
    }

    private func actTitles(in tasks: [RuleTask]) -> [String] {
        normalizedActTitles(tasks.map(\.title))
    }

    private func ruleMatches(place: Place, rule: HabitRule) -> Bool {
        if let placeId = rule.placeId {
            return placeId == place.id
        }

        return rule.placeCategory == place.category
    }

    private func enabledRuleTasks(_ rule: HabitRule, course: HabitCourse) -> [RuleTask] {
        let disabledTitles = Set(course.disabledActTitles.map(normalizedActTitle))
        return deduplicatedRuleTasks(rule.tasks).filter {
            !disabledTitles.contains(normalizedActTitle($0.title))
        }
    }

    private func deduplicatedRuleTasks(_ tasks: [RuleTask]) -> [RuleTask] {
        var seenTitles: Set<String> = []
        var result: [RuleTask] = []

        for task in tasks {
            let title = normalizedActTitle(task.title)
            guard !title.isEmpty, !seenTitles.contains(title) else { continue }
            seenTitles.insert(title)
            result.append(RuleTask(id: task.id, title: title))
        }

        return result
    }

    private func addCourseStep(courseId: UUID, place: Place, actTitle: String) {
        addCourseStep(courseId: courseId, place: place, actTitles: [actTitle])
    }

    private func addCourseStep(courseId: UUID, place: Place, actTitles: [String]) {
        let normalizedTitles = normalizedActTitles(actTitles)
        guard !normalizedTitles.isEmpty,
              courses.contains(where: { $0.id == courseId })
        else {
            return
        }

        for title in normalizedTitles where !acts.contains(where: { normalizedActTitle($0.title) == title }) {
            acts.append(RuleTask(title: title))
        }

        rules.append(
            HabitRule(
                courseId: courseId,
                placeId: place.id,
                placeCategory: place.category,
                triggerType: .enter,
                timeBlock: .any,
                weekdayType: .any,
                message: normalizedTitles.first ?? "",
                tasks: normalizedTitles.map { RuleTask(title: $0) }
            )
        )

        syncCourseTargetCategories(for: courseId)
    }

    private func syncCourseTargetCategories(for courseId: UUID) {
        guard let index = courses.firstIndex(where: { $0.id == courseId }) else { return }
        let categories = rules
            .filter { $0.courseId == courseId }
            .map(\.placeCategory)

        courses[index].targetCategories = orderedCategories(from: categories)
    }

    private func attachActToCourse(_ courseId: UUID, title: String) {
        guard let course = course(for: courseId) else { return }
        ensureRulesExist(for: course)

        for index in rules.indices where rules[index].courseId == courseId && course.targetCategories.contains(rules[index].placeCategory) {
            guard rules[index].triggerType == .enter else { continue }

            if !rules[index].tasks.contains(where: { normalizedActTitle($0.title) == title }) {
                rules[index].tasks.append(RuleTask(title: title))
            }

            rules[index].tasks = deduplicatedRuleTasks(rules[index].tasks)
            rules[index].message = rules[index].tasks.first?.title ?? title
            rules[index].isEnabled = true
        }
    }

    private func ensureRulesExist(for course: HabitCourse) {
        let existingTasks = deduplicatedRuleTasks(
            rules
                .filter { $0.courseId == course.id }
                .flatMap(\.tasks)
        )
        let fallbackMessage = existingTasks.first?.title ?? ""

        for category in course.targetCategories {
            let hasRule = rules.contains {
                $0.courseId == course.id &&
                $0.placeCategory == category &&
                $0.triggerType == .enter
            }

            guard !hasRule else { continue }

            rules.append(
                HabitRule(
                    courseId: course.id,
                    placeCategory: category,
                    triggerType: .enter,
                    timeBlock: .any,
                    weekdayType: .any,
                    message: fallbackMessage,
                    tasks: existingTasks,
                    isEnabled: !existingTasks.isEmpty
                )
            )
        }
    }

    private func orderedCategories(from categories: [PlaceCategory]) -> [PlaceCategory] {
        let selectedCategories = Set(categories)
        return PlaceCategory.allCases.filter { selectedCategories.contains($0) }
    }

    private func notificationMessage(for tasks: [RuleTask]) -> String {
        guard let firstTask = tasks.first else {
            return "できそうなことを1つだけ確認してみる"
        }

        if tasks.count > 1 {
            return "\(firstTask.title) ほか\(tasks.count - 1)件"
        }

        return firstTask.title
    }

    private func ensureLogTasks(at index: Int) {
        guard logs.indices.contains(index), logs[index].tasks.isEmpty else { return }
        logs[index].tasks = [fallbackStepTask(for: logs[index])]
    }

    private func fallbackStepTask(for log: TriggerLog) -> StepTask {
        StepTask(
            title: actionGuide(for: log).doText,
            isCompleted: log.userAction == .completed || log.userAction == .didAction
        )
    }

    private func markStepCompleteIfReady(at index: Int) {
        guard logs.indices.contains(index),
              !logs[index].tasks.isEmpty,
              logs[index].tasks.allSatisfy(\.isCompleted)
        else {
            return
        }

        logs[index].userAction = mergeUserAction(current: logs[index].userAction, incoming: .didAction)
    }

    private func normalizedMessage(_ message: String) -> String {
        let prefixes = [
            "{place}に着きました。",
            "駅に着きました。",
            "図書館に着きました。",
            "帰宅しました。",
            "ジムに着きました。",
            "職場に着きました。"
        ]

        for prefix in prefixes where message.hasPrefix(prefix) {
            return String(message.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return message
    }

    private func mergeUserAction(current: UserAction, incoming: UserAction) -> UserAction {
        if current.isResolved {
            return current
        }

        if incoming.isResolved {
            return incoming
        }

        switch (current, incoming) {
        case (.mapOpened, .opened):
            return .mapOpened
        default:
            return incoming
        }
    }

    private func syncRegionMonitoringIfReady() {
        guard hasBootstrapped else { return }
        locationService.syncMonitoring(for: places)
    }

    private func savePlaces() {
        guard hasBootstrapped else { return }
        store.save(places, to: "places.json")
    }

    private func saveCourses() {
        guard hasBootstrapped else { return }
        store.save(courses, to: "courses.json")
    }

    private func saveRules() {
        guard hasBootstrapped else { return }
        store.save(rules, to: "rules.json")
    }

    private func saveActs() {
        guard hasBootstrapped else { return }
        store.save(acts, to: "acts.json")
    }

    private func saveLogs() {
        guard hasBootstrapped else { return }
        store.save(logs, to: "logs.json")
    }

    private func saveAppTheme() {
        guard hasBootstrapped else { return }
        store.save(appTheme, to: "app_theme.json")
    }
}
