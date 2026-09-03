//
//  LocationService.swift
//  codippy
//
//  "¿Dónde estoy?": ubicación actual → código postal vía geocodificación inversa.
//

import CoreLocation
import Foundation
import Observation

struct LocationService {
    func currentPlace() async throws -> PostalPlace {
        let location = try await currentLocation()
        return try await GeocoderService().place(for: location)
    }

    /// Pide permiso si hace falta y devuelve la primera posición disponible.
    func currentLocation() async throws -> CLLocation {
        let manager = CLLocationManager()
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        let location = try await firstLocation()
        UserLocation.shared.location = location
        return location
    }

    /// Sin pedir permiso: solo devuelve algo si el usuario ya lo concedió.
    func currentLocationIfAuthorized() async -> CLLocation? {
        let status = CLLocationManager().authorizationStatus
        #if os(macOS)
        guard status == .authorizedAlways else { return nil }
        #else
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }
        #endif
        let location = try? await firstLocation()
        if let location { UserLocation.shared.location = location }
        return location
    }

    private func firstLocation() async throws -> CLLocation {
        var attempts = 0
        for try await update in CLLocationUpdate.liveUpdates() {
            if update.authorizationDenied || update.authorizationRestricted {
                throw PostalError.locationDenied
            }
            if let location = update.location {
                return location
            }
            attempts += 1
            if attempts > 20 { break }
        }
        throw PostalError.locationUnavailable
    }
}

/// Última ubicación conocida del usuario, para mostrar distancias en los resultados.
@Observable
final class UserLocation {
    static let shared = UserLocation()

    var location: CLLocation?

    func distance(to place: PostalPlace) -> CLLocationDistance? {
        place.distance(from: location)
    }

    /// Texto corto tipo "3,2 km" o "850 m" en las unidades del usuario.
    static func formatted(_ meters: CLLocationDistance) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
