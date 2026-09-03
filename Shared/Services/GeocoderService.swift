//
//  GeocoderService.swift
//  codippy
//
//  Búsqueda ciudad → código postal usando el geocoder de Apple (sin API externa).
//

import CoreLocation
import Foundation

struct GeocoderService {
    func searchPlace(_ name: String, countryCode: String) async throws -> [PostalPlace] {
        let countryName = Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
        let placemarks: [CLPlacemark]
        do {
            placemarks = try await CLGeocoder().geocodeAddressString("\(name), \(countryName)")
        } catch let error as CLError where error.code == .network {
            throw PostalError.offline
        } catch {
            throw PostalError.notFound
        }

        var results: [PostalPlace] = []
        for placemark in placemarks.prefix(3) {
            if let place = await place(from: placemark) {
                results.append(place)
            }
        }
        guard !results.isEmpty else { throw PostalError.notFound }

        let sameCountry = results.filter { $0.countryCode.caseInsensitiveCompare(countryCode) == .orderedSame }
        return sameCountry.isEmpty ? results : sameCountry
    }

    /// Barrio o distrito (subLocality) de unas coordenadas, si Apple lo conoce.
    func neighborhood(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        return placemark?.subLocality
    }

    func place(for location: CLLocation) async throws -> PostalPlace {
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first,
              let place = place(fromResolved: placemark) else {
            throw PostalError.locationUnavailable
        }
        return place
    }

    /// El geocodificado directo de una ciudad no suele traer código postal;
    /// se resuelve geocodificando a la inversa sus coordenadas.
    private func place(from placemark: CLPlacemark) async -> PostalPlace? {
        var resolved = placemark
        if resolved.postalCode == nil, let location = resolved.location,
           let reversed = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            resolved = reversed
        }
        return place(fromResolved: resolved)
    }

    private func place(fromResolved placemark: CLPlacemark) -> PostalPlace? {
        guard let postalCode = placemark.postalCode else { return nil }
        let street = placemark.thoroughfare.map { thoroughfare in
            placemark.subThoroughfare.map { "\(thoroughfare), \($0)" } ?? thoroughfare
        }
        return PostalPlace(
            countryCode: placemark.isoCountryCode ?? "",
            postalCode: postalCode,
            placeName: placemark.locality ?? placemark.name ?? "",
            state: placemark.administrativeArea ?? "",
            latitude: placemark.location?.coordinate.latitude,
            longitude: placemark.location?.coordinate.longitude,
            neighborhood: placemark.subLocality,
            street: street,
            province: placemark.subAdministrativeArea
        )
    }
}
