import CoreLocation
import Foundation

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private enum PersistedRegionState: String, Codable {
        case unknown
        case inside
        case outside

        init?(_ state: CLRegionState) {
            switch state {
            case .inside:
                self = .inside
            case .outside:
                self = .outside
            case .unknown:
                self = .unknown
            @unknown default:
                return nil
            }
        }
    }

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastKnownLocation: CLLocation?
    @Published private(set) var monitoredRegionCount: Int = 0

    var onRegionEvent: ((UUID, TriggerType) -> Void)?
    var onAuthorizationChanged: (() -> Void)?

    private static let regionStateFileName = "region_states.json"
    private let manager = CLLocationManager()
    private let store = LocalStore()
    private let maximumHabitRegions = 20
    private var monitoredRegionIdentifiers: Set<String> = []
    private var persistedRegionStates: [String: PersistedRegionState]

    override init() {
        authorizationStatus = manager.authorizationStatus
        persistedRegionStates = store.load([String: PersistedRegionState].self, from: Self.regionStateFileName) ?? [:]
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestCurrentLocation() {
        manager.requestLocation()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = manager.authorizationStatus
    }

    func syncMonitoring(for places: [Place]) {
        stopMonitoringHabitRegions()

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self),
              authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
        else {
            monitoredRegionIdentifiers = []
            monitoredRegionCount = 0
            return
        }

        let enabledPlaces = places
            .filter { $0.isEnabled }
            .prefix(maximumHabitRegions)

        monitoredRegionIdentifiers = Set(enabledPlaces.map { $0.id.uuidString })
        prunePersistedRegionStates()

        for place in enabledPlaces {
            let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            let radius = normalizedRadius(place.radius)
            let region = CLCircularRegion(center: center, radius: radius, identifier: place.id.uuidString)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
        }

        monitoredRegionCount = enabledPlaces.count
    }

    private func stopMonitoringHabitRegions() {
        for region in manager.monitoredRegions {
            if UUID(uuidString: region.identifier) != nil {
                manager.stopMonitoring(for: region)
            }
        }
    }

    private func normalizedRadius(_ radius: Double) -> CLLocationDistance {
        let minimumRadius = 50.0
        let requestedRadius = max(radius, minimumRadius)

        guard manager.maximumRegionMonitoringDistance > 0 else {
            return requestedRadius
        }

        return min(requestedRadius, manager.maximumRegionMonitoringDistance)
    }

    private func handle(region: CLRegion, triggerType: TriggerType) {
        guard let placeId = UUID(uuidString: region.identifier) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onRegionEvent?(placeId, triggerType)
        }
    }

    private func persistRegionStates() {
        store.save(persistedRegionStates, to: Self.regionStateFileName)
    }

    private func prunePersistedRegionStates() {
        let previous = persistedRegionStates
        persistedRegionStates = persistedRegionStates.filter { monitoredRegionIdentifiers.contains($0.key) }
        if previous != persistedRegionStates {
            persistRegionStates()
        }
    }

    private func updatePersistedState(_ state: PersistedRegionState, for identifier: String) {
        guard persistedRegionStates[identifier] != state else { return }
        persistedRegionStates[identifier] = state
        persistRegionStates()
    }

    private func refreshMonitoredRegionStates() {
        for region in manager.monitoredRegions where monitoredRegionIdentifiers.contains(region.identifier) {
            manager.requestState(for: region)
        }
    }

    private func recoverEventIfNeeded(for region: CLRegion, newState: PersistedRegionState) {
        guard monitoredRegionIdentifiers.contains(region.identifier) else { return }

        let previousState = persistedRegionStates[region.identifier] ?? .unknown
        updatePersistedState(newState, for: region.identifier)

        switch (previousState, newState) {
        case (.outside, .inside):
            handle(region: region, triggerType: .enter)
        case (.inside, .outside):
            handle(region: region, triggerType: .exit)
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = manager.authorizationStatus
            self?.onAuthorizationChanged?()

            if manager.authorizationStatus.allowsRegionMonitoring {
                self?.requestCurrentLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        guard monitoredRegionIdentifiers.contains(region.identifier) else { return }
        manager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let previousState = persistedRegionStates[region.identifier] ?? .unknown
        updatePersistedState(.inside, for: region.identifier)

        if previousState != .inside {
            handle(region: region, triggerType: .enter)
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let previousState = persistedRegionStates[region.identifier] ?? .unknown
        updatePersistedState(.outside, for: region.identifier)

        if previousState != .outside {
            handle(region: region, triggerType: .exit)
        }
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let persistedState = PersistedRegionState(state) else { return }
        recoverEventIfNeeded(for: region, newState: persistedState)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async { [weak self] in
            self?.lastKnownLocation = locations.last
            self?.refreshMonitoredRegionStates()
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("LocationService monitoring failed: \(error)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationService failed: \(error)")
    }
}

extension CLAuthorizationStatus {
    var habitRouteDisplayName: String {
        switch self {
        case .notDetermined:
            return "未確認"
        case .restricted:
            return "制限中"
        case .denied:
            return "拒否"
        case .authorizedAlways:
            return "常に許可"
        case .authorizedWhenInUse:
            return "使用中のみ許可"
        @unknown default:
            return "不明"
        }
    }

    var allowsRegionMonitoring: Bool {
        self == .authorizedAlways || self == .authorizedWhenInUse
    }
}
