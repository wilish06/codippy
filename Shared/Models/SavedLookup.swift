//
//  SavedLookup.swift
//  codippy
//

import Foundation
import SwiftData

@Model
final class SavedLookup {
    var countryCode: String
    var postalCode: String
    var placeName: String
    var state: String
    var latitude: Double?
    var longitude: Double?
    var neighborhood: String?
    var street: String?
    var province: String?
    var timestamp: Date
    var isFavorite: Bool

    init(place: PostalPlace, timestamp: Date = .now, isFavorite: Bool = false) {
        self.countryCode = place.countryCode
        self.postalCode = place.postalCode
        self.placeName = place.placeName
        self.state = place.state
        self.latitude = place.latitude
        self.longitude = place.longitude
        self.neighborhood = place.neighborhood
        self.street = place.street
        self.province = place.province
        self.timestamp = timestamp
        self.isFavorite = isFavorite
    }

    var place: PostalPlace {
        PostalPlace(
            countryCode: countryCode,
            postalCode: postalCode,
            placeName: placeName,
            state: state,
            latitude: latitude,
            longitude: longitude,
            neighborhood: neighborhood,
            street: street,
            province: province
        )
    }
}
