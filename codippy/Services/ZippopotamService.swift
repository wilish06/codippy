//
//  ZippopotamService.swift
//  codippy
//
//  Cliente de https://api.zippopotam.us — API gratuita sin clave.
//

import Foundation

struct ZippopotamService {
    private struct CodeResponse: Decodable {
        let postCode: String
        let countryAbbreviation: String
        let places: [Place]

        struct Place: Decodable {
            let placeName: String
            let state: String
            let stateAbbreviation: String
            let latitude: String
            let longitude: String

            enum CodingKeys: String, CodingKey {
                case placeName = "place name"
                case state
                case stateAbbreviation = "state abbreviation"
                case latitude
                case longitude
            }
        }

        enum CodingKeys: String, CodingKey {
            case postCode = "post code"
            case countryAbbreviation = "country abbreviation"
            case places
        }
    }

    private struct PlaceResponse: Decodable {
        let countryAbbreviation: String
        let state: String
        let places: [Place]

        struct Place: Decodable {
            let placeName: String
            let postCode: String
            let latitude: String
            let longitude: String

            enum CodingKeys: String, CodingKey {
                case placeName = "place name"
                case postCode = "post code"
                case latitude
                case longitude
            }
        }

        enum CodingKeys: String, CodingKey {
            case countryAbbreviation = "country abbreviation"
            case state
            case places
        }
    }

    func lookup(code: String, country: String) async throws -> [PostalPlace] {
        let decoded: CodeResponse = try await fetch(path: "\(country.lowercased())/\(escaped(code))")
        return decoded.places.map { place in
            PostalPlace(
                countryCode: decoded.countryAbbreviation,
                postalCode: decoded.postCode,
                placeName: place.placeName,
                state: place.state,
                latitude: Double(place.latitude),
                longitude: Double(place.longitude)
            )
        }
    }

    /// Abreviatura de la comunidad/estado a la que pertenece un código postal.
    func stateAbbreviation(code: String, country: String) async throws -> String? {
        let decoded: CodeResponse = try await fetch(path: "\(country.lowercased())/\(escaped(code))")
        return decoded.places.first?.stateAbbreviation
    }

    /// Todos los códigos postales de una población dentro de una comunidad/estado.
    func searchPlace(name: String, stateAbbreviation: String, country: String) async throws -> [PostalPlace] {
        let path = "\(country.lowercased())/\(escaped(stateAbbreviation.lowercased()))/\(escaped(name))"
        let decoded: PlaceResponse = try await fetch(path: path)
        return decoded.places.map { place in
            PostalPlace(
                countryCode: decoded.countryAbbreviation,
                postalCode: place.postCode,
                placeName: place.placeName,
                state: decoded.state,
                latitude: Double(place.latitude),
                longitude: Double(place.longitude)
            )
        }
    }

    private func escaped(_ component: String) -> String {
        component.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? component
    }

    private func fetch<Response: Decodable>(path: String) async throws -> Response {
        guard let url = URL(string: "https://api.zippopotam.us/\(path)") else {
            throw PostalError.badResponse
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw PostalError.badResponse }
        guard http.statusCode == 200 else { throw PostalError.notFound }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
