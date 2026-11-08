import CoreLocation
import MapKit
import Observation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let geocoder = CLGeocoder()

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var latitude: Double?
    var longitude: Double?
    var city: String = ""
    var isUsingFallback: Bool = false
    var lastError: String?

    let fallbackLatitude: Double = 40.7128
    let fallbackLongitude: Double = -74.0060

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 200
        authorizationStatus = manager.authorizationStatus
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: latitude ?? fallbackLatitude,
            longitude: longitude ?? fallbackLongitude
        )
    }

    var hasRealLocation: Bool { latitude != nil && longitude != nil }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func requestPermission() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            beginUpdating()
        }
    }

    func beginUpdating() {
        guard isAuthorized else { return }
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    func applyFallbackCity() {
        isUsingFallback = true
        city = "New York, NY"
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.authorizationStatus = status
            if self.isAuthorized {
                manager.startUpdatingLocation()
            } else if status == .denied || status == .restricted {
                self.isUsingFallback = true
                self.applyFallbackCity()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.isUsingFallback = false
            self.resolveCity(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.lastError = error.localizedDescription
        }
    }

    private func resolveCity(for location: CLLocation) {
        Task { @MainActor in
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
               let placemark = placemarks.first {
                let locality = placemark.locality ?? placemark.subAdministrativeArea ?? ""
                let state = placemark.administrativeArea ?? ""
                city = state.isEmpty ? locality : "\(locality), \(state)"
            }
        }
    }
}
