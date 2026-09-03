//
//  PostalPlace.swift
//  codippy
//

import CoreLocation
import Foundation

struct PostalPlace: Codable, Hashable, Identifiable {
    var countryCode: String
    var postalCode: String
    var placeName: String
    var state: String
    var latitude: Double?
    var longitude: Double?
    /// Barrio o distrito, resuelto a posteriori por geocodificación inversa.
    var neighborhood: String?
    /// Calle (con número si lo hay), cuando la búsqueda es a nivel de calle.
    var street: String?
    /// Provincia (segundo nivel administrativo), cuando la fuente la da.
    var province: String?

    var id: String { "\(countryCode)|\(postalCode)|\(placeName)|\(state)|\(street ?? "")" }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation? {
        guard let latitude, let longitude else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    var countryName: String {
        Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
    }

    /// Línea secundaria para listas: la provincia si aporta algo; si no, la región.
    var regionLine: String? {
        if let province, !province.isEmpty,
           province.caseInsensitiveCompare(placeName) != .orderedSame {
            return province
        }
        return state.isEmpty ? nil : state
    }

    /// Dirección completa en una línea, lista para pegar en un formulario.
    var fullAddress: String {
        var parts: [String] = []
        if let street, !street.isEmpty { parts.append(street) }
        parts.append("\(postalCode) \(placeName)".trimmingCharacters(in: .whitespaces))
        if let province, !province.isEmpty, province.caseInsensitiveCompare(placeName) != .orderedSame {
            parts.append(province)
        }
        if !state.isEmpty, state.caseInsensitiveCompare(province ?? "") != .orderedSame,
           state.caseInsensitiveCompare(placeName) != .orderedSame {
            parts.append(state)
        }
        parts.append(countryName)
        return parts.joined(separator: ", ")
    }

    /// Distancia en metros desde una ubicación, si ambas coordenadas existen.
    func distance(from origin: CLLocation?) -> CLLocationDistance? {
        guard let origin, let location else { return nil }
        return origin.distance(from: location)
    }
}
