//
//  LocationService.swift
//  codippy
//
//  "¿Dónde estoy?": ubicación actual → código postal vía geocodificación inversa.
//

import CoreLocation
import Foundation

struct LocationService {
    func currentPlace() async throws -> PostalPlace {
        let manager = CLLocationManager()
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        var attempts = 0
        for try await update in CLLocationUpdate.liveUpdates() {
            if update.authorizationDenied || update.authorizationRestricted {
                throw PostalError.locationDenied
            }
            if let location = update.location {
                return try await GeocoderService().place(for: location)
            }
            attempts += 1
            if attempts > 20 { break }
        }
        throw PostalError.locationUnavailable
    }
}
