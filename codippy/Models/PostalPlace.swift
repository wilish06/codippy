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

    var id: String { "\(countryCode)|\(postalCode)|\(placeName)|\(state)|\(street ?? "")" }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
