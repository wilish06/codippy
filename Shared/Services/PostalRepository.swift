//
//  PostalRepository.swift
//  codippy
//
//  Decide la fuente de datos: dataset offline (empaquetado o descargado) si
//  existe para el país; si no, API de Zippopotam para códigos y geocoder de
//  Apple para ciudades y calles.
//

import CoreLocation
import Foundation
import Observation

@Observable
final class PostalRepository {
    private let dataset = DatasetProvider.shared
    private let api = ZippopotamService()
    private let geocoder = GeocoderService()

    /// Países soportados por Zippopotam que ofrecemos en el selector.
    static let onlineCountries = [
        "ES", "PT", "FR", "DE", "IT", "GB", "NL", "BE", "CH", "AT",
        "PL", "CZ", "SK", "DK", "SE", "NO", "FI", "HU", "HR", "RO",
        "US", "CA", "MX", "AR", "BR", "JP", "IN", "AU", "NZ", "ZA",
        "TR", "RU", "AD",
    ]

    var countries: [CountryOption] {
        let codes = Set(Self.onlineCountries).union(dataset.availableCountries)
        return codes
            .map { CountryOption(code: $0, isOffline: dataset.hasDataset(for: $0)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func supports(country: String) -> Bool {
        countries.contains { $0.code == country.uppercased() }
    }

    func search(_ query: String, country: String) async throws -> [PostalPlace] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        if Self.looksLikePostalCode(text) {
            try Self.validate(code: text, country: country)
            return try await lookup(code: text, country: country)
        }
        return try await searchPlace(text, country: country)
    }

    /// "28001" o "SW1A 1AA" son códigos; "Gran Vía 12" o "Sevilla" no.
    static func looksLikePostalCode(_ text: String) -> Bool {
        let tokens = text.split { $0 == " " || $0 == "-" }
        guard text.contains(where: \.isNumber), tokens.count <= 2 else { return false }
        // Una palabra puramente alfabética delata un nombre de calle o ciudad.
        return !tokens.contains { $0.count >= 3 && $0.allSatisfy(\.isLetter) }
    }

    /// Evita consultas inútiles: códigos a medio escribir o imposibles en el país.
    private static func validate(code: String, country: String) throws {
        guard let format = PostalCodeFormat.format(for: country) else { return }
        let countryName = Locale.current.localizedString(forRegionCode: country) ?? country
        guard format.isComplete(code) else {
            throw PostalError.incompleteCode(country: countryName, example: format.example)
        }
        guard format.matches(code) else {
            throw PostalError.invalidFormat(country: countryName, example: format.example)
        }
    }

    func lookup(code: String, country: String) async throws -> [PostalPlace] {
        if dataset.hasDataset(for: country) {
            return try dataset.lookup(code: code, country: country)
        }
        return try await api.lookup(code: code, country: country)
    }

    func searchPlace(_ name: String, country: String) async throws -> [PostalPlace] {
        if dataset.hasDataset(for: country) {
            // Los datasets solo tienen poblaciones; si no hay match puede ser
            // una calle, así que se intenta con el geocoder (necesita red).
            if let matches = try? dataset.search(place: name, country: country) {
                return matches
            }
            return try await geocoder.searchPlace(name, countryCode: country)
        }

        let seeds = try await geocoder.searchPlace(name, countryCode: country)

        // Resultado a nivel de calle: se devuelve tal cual, sin expandir a la ciudad.
        if seeds.contains(where: { $0.street != nil }) {
            return seeds
        }

        // Búsqueda de ciudad: con el código "semilla" sacamos la comunidad y con
        // ella pedimos a Zippopotam TODOS los códigos de la ciudad.
        guard let seed = seeds.first,
              let abbreviation = try? await api.stateAbbreviation(code: seed.postalCode, country: country) else {
            return seeds
        }
        for candidate in [seed.placeName, name] where !candidate.isEmpty {
            if let all = try? await api.searchPlace(name: candidate, stateAbbreviation: abbreviation, country: country),
               !all.isEmpty {
                return all
            }
        }
        return seeds
    }

    /// Códigos postales vecinos (solo con dataset offline del país).
    func nearby(to place: PostalPlace) -> [(place: PostalPlace, distance: CLLocationDistance)] {
        dataset.nearby(to: place)
    }

    /// Barrio de un código postal por geocodificación inversa, con caché.
    private var neighborhoodCache: [String: String?] = [:]

    func neighborhood(for place: PostalPlace) async -> String? {
        guard let latitude = place.latitude, let longitude = place.longitude else { return nil }
        let key = "\(place.countryCode)|\(place.postalCode)"
        if let cached = neighborhoodCache[key] { return cached }
        let resolved = await geocoder.neighborhood(latitude: latitude, longitude: longitude)
        neighborhoodCache[key] = resolved
        return resolved
    }
}

struct CountryOption: Identifiable, Hashable {
    let code: String
    let isOffline: Bool

    var id: String { code }
    var name: String { Locale.current.localizedString(forRegionCode: code) ?? code }
}
