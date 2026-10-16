/// Where the shopper is: location permission, nearby Kroger-family stores, and the store their
/// prices come from. Asking for location waits for a tap ("Use my location"), unless permission
/// was granted before; inside a store (within ~200 m) it's chosen automatically.

import CoreLocation
import Foundation
import FoodGenieKit

@MainActor
@Observable
final class StoreModel: NSObject, CLLocationManagerDelegate {
    enum Permission { case unknown, granted, denied }

    private(set) var permission: Permission = .unknown
    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var nearby: Nearby?
    /// The store prices come from.
    private(set) var store: Store?
    /// The shopper is standing in `store`.
    private(set) var inStore = false
    private(set) var loading = false
    private(set) var error: String?

    /// Located, but no Kroger-family store nearby (e.g. a state without one).
    var noStores: Bool { nearby.map { $0.stores.isEmpty } ?? false }

    @ObservationIgnored private let api: APIClient
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var authorization: CheckedContinuation<CLAuthorizationStatus, Never>?
    @ObservationIgnored private var started = false
    private static let savedKey = "store"

    init(api: APIClient) {
        self.api = api
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if let data = UserDefaults.standard.data(forKey: Self.savedKey) {
            store = try? JSONDecoder().decode(Store.self, from: data)
        }
    }

    /// At launch: locate right away only when permission was already given.
    func start() async {
        guard !started else { return }
        started = true
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: await locate()
        case .denied, .restricted: permission = .denied
        default: break
        }
    }

    func locate() async {
        loading = true
        error = nil
        defer { loading = false }

        let status = await requestAuthorization()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            permission = .denied
            return
        }
        permission = .granted
        do {
            let here = try await currentLocation()
            coordinate = here.coordinate
            let result = try await api.nearby(lat: here.coordinate.latitude, lng: here.coordinate.longitude)
            nearby = result
            if let at = result.atStore {
                select(at, inStore: true)
            } else {
                inStore = false
                if store == nil, let first = result.stores.first { select(first, inStore: false) }
            }
        } catch is CancellationError {
            // the view went away
        } catch let e as APIError {
            error = e.message
        } catch {
            self.error = "Couldn’t get your location."
        }
    }

    func choose(_ s: Store) {
        select(s, inStore: nearby?.atStore?.locationId == s.locationId)
    }

    private func select(_ s: Store, inStore: Bool) {
        store = s
        self.inStore = inStore
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: Self.savedKey) }
    }

    // MARK: Core Location

    private func requestAuthorization() async -> CLAuthorizationStatus {
        let status = manager.authorizationStatus
        guard status == .notDetermined else { return status }
        return await withCheckedContinuation { continuation in
            authorization?.resume(returning: .notDetermined)
            authorization = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    /// A fix from the last five minutes, else a fresh one.
    private func currentLocation() async throws -> CLLocation {
        if let last = manager.location, last.timestamp.timeIntervalSinceNow > -300 { return last }
        for try await update in CLLocationUpdate.liveUpdates() {
            if let location = update.location { return location }
        }
        throw APIError("Couldn’t get your location.")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined, let continuation = self.authorization else { return }
            self.authorization = nil
            continuation.resume(returning: status)
        }
    }
}
