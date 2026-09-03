//
//  AppRouter.swift
//  codippy
//
//  Entradas externas a la app (esquema de URL codippy://, App Intents, widget,
//  extensión de compartir, servicio de macOS) convertidas en una navegación
//  pendiente que la pantalla de búsqueda consume.
//
//  URLs admitidas:
//    codippy://search?q=28001&country=ES
//    codippy://smart?text=<texto libre con una dirección>
//    codippy://locate
//

import Foundation
import Observation

@Observable
final class AppRouter {
    static let shared = AppRouter()
    static let scheme = "codippy"

    enum Destination: Equatable {
        case search(query: String, country: String?)
        case smartText(String)
        case locate
    }

    enum Tab: Hashable {
        case search
        case history
    }

    var pending: Destination?
    var selectedTab: Tab = .search

    func go(_ destination: Destination) {
        selectedTab = .search
        pending = destination
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == Self.scheme else { return false }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        switch url.host()?.lowercased() {
        case "search":
            guard let query = value("q"), !query.isEmpty else { return false }
            go(.search(query: query, country: value("country")?.uppercased()))
        case "smart":
            guard let text = value("text"), !text.isEmpty else { return false }
            go(.smartText(text))
        case "locate":
            go(.locate)
        default:
            return false
        }
        return true
    }

    // MARK: - Construcción de URLs

    static func searchURL(query: String, country: String?) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "search"
        var items = [URLQueryItem(name: "q", value: query)]
        if let country, !country.isEmpty { items.append(URLQueryItem(name: "country", value: country)) }
        components.queryItems = items
        return components.url!
    }

    static func searchURL(for place: PostalPlace) -> URL {
        searchURL(query: place.postalCode, country: place.countryCode)
    }

    static func smartURL(text: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "smart"
        components.queryItems = [URLQueryItem(name: "text", value: text)]
        return components.url!
    }

    static var locateURL: URL { URL(string: "\(scheme)://locate")! }
}
