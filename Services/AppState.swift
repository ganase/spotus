import Foundation

enum AppTab: Hashable {
    case home
    case actionCenter
    case course
    case place
    case rule
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

    @Published var logs: [TriggerLog] = [] {
        didSet {
            saveLogs()
        }
    }

    @Published var mapSelection: MapSelection?
    @Published var selectedTab: AppTab = .home
    @Published var focusedLogId: UUID?

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

        places = store.load([Place].self, from: "places.json") ?? PresetData.places
        courses = store.load([HabitCourse].self, from: "courses.json") ?? PresetData.courses
        rules = store.load([HabitRule].self, from: "rules.json") ?? PresetData.rules
        logs = store.load([TriggerLog].self, from: "logs.json") ?? []

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

    func updateRuleMessage(ruleId: UUID, message: String) {
        guard let index = rules.firstIndex(where: { $0.id == ruleId }) else { return }
        rules[index].message = message
    }

    func rule(for ruleId: UUID) -> HabitRule? {
        rules.first { $0.id == ruleId }
    }

    func presetRuleMessage(for ruleId: UUID) -> String? {
        PresetData.rules.first { $0.id == ruleId }?.message
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

    func showMap(for placeId: UUID) {
        guard place(for: placeId) != nil else { return }
        requestCurrentLocation()
        mapSelection = MapSelection(placeId: placeId)
    }

    func openActionCenter(for logId: UUID) {
        focusedLogId = logId
        selectedTab = .actionCenter
    }

    func focusLog(_ logId: UUID) {
        focusedLogId = logId
    }

    func actionGuide(for log: TriggerLog) -> ActionGuide {
        if let actionGuide = log.actionGuide {
            return actionGuide
        }
        return fallbackGuide(for: log)
    }

    func markDidAction(logId: UUID) {
        updateLogAction(logId: logId, action: .didAction)
        openActionCenter(for: logId)
    }

    func markAvoidedAction(logId: UUID) {
        updateLogAction(logId: logId, action: .avoidedAction)
        openActionCenter(for: logId)
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

        let match = RuleEngine.bestMatch(
            for: place,
            triggerType: triggerType,
            date: Date(),
            courses: courses,
            rules: rules
        )

        guard let payload = notificationPayload(for: place, triggerType: triggerType, match: match) else {
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
            actionGuide: payload.actionGuide
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

    private func notificationPayload(for place: Place, triggerType: TriggerType, match: RuleMatch?) -> (title: String, subtitle: String, message: String, courseId: UUID?, actionGuide: ActionGuide)? {
        if let match {
            return (
                notificationTitle(for: place),
                match.course.name,
                match.message,
                match.course.id,
                guide(for: place, match: match)
            )
        }

        guard triggerType == .enter,
              courses.contains(where: { $0.isEnabled && $0.targetCategories.contains(place.category) })
        else {
            return nil
        }

        return (
            notificationTitle(for: place),
            "Spotus",
            fallbackMessage(for: place),
            nil,
            fallbackGuide(for: place)
        )
    }

    private func fallbackMessage(for place: Place) -> String {
        switch place.category {
        case .home:
            return "帰宅しました。今日の小さな習慣を1つだけ進めましょう。"
        case .station:
            return "\(place.name)に着きました。移動時間で5分だけ習慣を進めましょう。"
        case .office:
            return "\(place.name)に着きました。最初の5分で一番大事なことから始めましょう。"
        case .gym:
            return "ジムに着きました。まず5分だけ体を動かしましょう。"
        case .library:
            return "図書館に着きました。まず10分だけ静かな時間を作りましょう。"
        case .barArea:
            return "\(place.name)に着きました。今日はどう過ごしたいかを1回だけ思い出しましょう。"
        case .convenienceStore:
            return "\(place.name)に着きました。買う前に、本当に必要なものだけ確認しましょう。"
        case .other:
            return "\(place.name)に着きました。1分だけでも習慣を進めましょう。"
        }
    }

    private func isDuplicateEvent(for placeId: UUID, triggerType: TriggerType) -> Bool {
        guard let latestLog = logs.first(where: { $0.placeId == placeId && $0.triggerType == triggerType }) else {
            return false
        }

        return Date().timeIntervalSince(latestLog.triggeredAt) < duplicateNotificationWindow
    }

    private func notificationTitle(for place: Place) -> String {
        "\(place.category.notificationEmoji) \(place.name)で次の一歩"
    }

    private func guide(for place: Place, match: RuleMatch) -> ActionGuide {
        PresetData.guide(for: match.rule.id) ?? fallbackGuide(for: place)
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
                doText: "帰宅後すぐに小さな習慣を1つ始める",
                avoidText: "そのままだらだら過ごし始める"
            )
        case .station:
            return ActionGuide(
                doText: "移動時間の最初の5分を習慣に使う",
                avoidText: "乗車時間を何となく流す"
            )
        case .office:
            return ActionGuide(
                doText: "最初の5分で一番大事な作業に着手する",
                avoidText: "雑務から始める"
            )
        case .gym:
            return ActionGuide(
                doText: "5分だけでも体を動かし始める",
                avoidText: "着いてから長く迷う"
            )
        case .library:
            return ActionGuide(
                doText: "10分だけ静かな集中時間を作る",
                avoidText: "別の作業に気を取られる"
            )
        case .barArea:
            return ActionGuide(
                doText: "そのまま帰るか、水だけで切り上げる",
                avoidText: "流れで店に入る"
            )
        case .convenienceStore:
            return ActionGuide(
                doText: "必要なものだけ確認して買う",
                avoidText: "ついで買いを増やす"
            )
        case .other:
            return ActionGuide(
                doText: "1分だけでも習慣を始める",
                avoidText: "また後でにする"
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
            openActionCenter(for: logId)
        case .mapOpened:
            if let placeId {
                showMap(for: placeId)
            }
        case .ignored, .completed, .didAction, .avoidedAction, .dismissed:
            break
        }
    }

    private func updateLogAction(logId: UUID, action: UserAction) {
        guard let index = logs.firstIndex(where: { $0.id == logId }) else { return }
        logs[index].userAction = mergeUserAction(current: logs[index].userAction, incoming: action)
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

    private func saveLogs() {
        guard hasBootstrapped else { return }
        store.save(logs, to: "logs.json")
    }
}
