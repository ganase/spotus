import Foundation

@MainActor
final class AppState: ObservableObject {
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

    let notificationService = NotificationService()
    let locationService = LocationService()

    private let store = LocalStore()
    private var hasBootstrapped = false

    init() {
        notificationService.onResponse = { [weak self] logId, action in
            Task { @MainActor in
                self?.updateLogAction(logId: logId, action: action)
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

        places = store.load([Place].self, from: "places.json") ?? []
        courses = store.load([HabitCourse].self, from: "courses.json") ?? PresetData.courses
        rules = store.load([HabitRule].self, from: "rules.json") ?? PresetData.rules
        logs = store.load([TriggerLog].self, from: "logs.json") ?? []

        hasBootstrapped = true
        notificationService.refreshAuthorizationStatus()
        locationService.refreshAuthorizationStatus()
        syncRegionMonitoringIfReady()
    }

    func requestNotificationPermission() {
        notificationService.requestAuthorization()
    }

    func requestLocationPermission() {
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

    func testEnterTrigger(for place: Place) {
        handleRegionEvent(placeId: place.id, triggerType: .enter)
    }

    func placeName(for placeId: UUID) -> String {
        places.first(where: { $0.id == placeId })?.name ?? "削除済みの場所"
    }

    func courseName(for courseId: UUID?) -> String {
        guard let courseId else { return "該当コースなし" }
        return courses.first(where: { $0.id == courseId })?.name ?? "削除済みのコース"
    }

    private func handleRegionEvent(placeId: UUID, triggerType: TriggerType) {
        guard let place = places.first(where: { $0.id == placeId && $0.isEnabled }) else { return }

        guard let match = RuleEngine.bestMatch(
            for: place,
            triggerType: triggerType,
            date: Date(),
            courses: courses,
            rules: rules
        ) else {
            return
        }

        let log = TriggerLog(
            placeId: place.id,
            courseId: match.course.id,
            triggerType: triggerType,
            message: match.message
        )

        logs.insert(log, at: 0)
        logs = Array(logs.prefix(200))

        notificationService.deliver(
            title: match.course.name,
            body: match.message,
            logId: log.id,
            placeId: place.id,
            courseId: match.course.id
        )
    }

    private func updateLogAction(logId: UUID, action: UserAction) {
        guard let index = logs.firstIndex(where: { $0.id == logId }) else { return }
        logs[index].userAction = action
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
