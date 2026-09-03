//
//  CodippyIntents.swift
//  codippy
//
//  App Intents para Atajos, Siri y Spotlight.
//

import AppIntents
import Foundation

/// Abre la app con una búsqueda ya lanzada.
struct OpenSearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Buscar en Codippy"
    static let description = IntentDescription("Abre Codippy y busca un código postal, ciudad o calle.")
    static let openAppWhenRun = true

    @Parameter(title: "Búsqueda", requestValueDialog: "¿Qué código postal, ciudad o calle quieres buscar?")
    var query: String

    @Parameter(title: "País (ISO, opcional)", default: nil)
    var country: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Buscar \(\.$query) en Codippy") {
            \.$country
        }
    }

    func perform() async throws -> some IntentResult {
        AppRouter.shared.go(.search(query: query, country: country?.uppercased()))
        return .result()
    }
}

/// Devuelve el código postal sin abrir la app: ideal para automatizaciones.
struct LookupPostalCodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Obtener código postal"
    static let description = IntentDescription("Busca un lugar y devuelve su código postal como texto.")

    @Parameter(title: "Ciudad o dirección", requestValueDialog: "¿De qué ciudad o dirección quieres el código postal?")
    var query: String

    @Parameter(title: "País (ISO, opcional)", default: nil)
    var country: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Código postal de \(\.$query)") {
            \.$country
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let countryCode = country?.uppercased()
            ?? UserDefaults.standard.string(forKey: "selectedCountry")
            ?? Locale.current.region?.identifier
            ?? "ES"
        let results = try await PostalRepository().search(query, country: countryCode)
        guard let first = results.first else { throw PostalError.notFound }
        let codes = Array(Set(results.map(\.postalCode))).sorted()
        let dialog: IntentDialog = codes.count > 1
            ? "\(first.placeName) tiene \(codes.count) códigos postales; el primero es \(first.postalCode)."
            : "El código postal de \(first.placeName) es \(first.postalCode)."
        return .result(value: first.postalCode, dialog: dialog)
    }
}

/// "¿Cuál es mi código postal?"
struct CurrentPostalCodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Mi código postal"
    static let description = IntentDescription("Devuelve el código postal de tu ubicación actual.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let place = try await LocationService().currentPlace()
        return .result(
            value: place.postalCode,
            dialog: "Estás en \(place.postalCode), \(place.placeName)."
        )
    }
}

struct CodippyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LookupPostalCodeIntent(),
            phrases: [
                "Busca un código postal con \(.applicationName)",
                "Código postal con \(.applicationName)",
            ],
            shortTitle: "Buscar código postal",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: CurrentPostalCodeIntent(),
            phrases: [
                "Mi código postal con \(.applicationName)",
                "¿Cuál es mi código postal según \(.applicationName)?",
            ],
            shortTitle: "Mi código postal",
            systemImageName: "location"
        )
    }
}
