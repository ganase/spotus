import CoreLocation
import Foundation

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastKnownLocation: CLLocation?
    @Published private(set) var monitoredRegionCount: Int = 0

    var onRegionEvent: ((UUID, TriggerType) -> Void)?
    var onAuthorizationChanged: (() -> Void)?

    private let manager = CLLocationManager()
    private let maximumHabitRegions = 20

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
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
            monitoredRegionCount = 0
            return
        }

        let enabledPlaces = places
            .filter { $0.isEnabled }
            .prefix(maximumHabitRegions)

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

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = manager.authorizationStatus
            self?.onAuthorizationChanged?()
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        handle(region: region, triggerType: .enter)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        handle(region: region, triggerType: .exit)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async { [weak self] in
            self?.lastKnownLocation = locations.last
        }
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
