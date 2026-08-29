//
//  IntelligenceService.swift
//  codippy
//
//  Funciones de IA con el modelo on-device de Apple (Foundation Models):
//  - Extraer una dirección estructurada de texto "sucio" (emails, WhatsApp, OCR).
//  - Resumen breve de la zona de un código postal.
//  Todo local: sin red, sin coste y compatible con el modo offline de la app.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Consulta lista para lanzar por el flujo de búsqueda normal.
struct SmartQuery {
    let query: String
    let countryCode: String?
}

enum IntelligenceService {
    /// El modelo requiere Apple Intelligence activado y hardware compatible.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
        #else
        return false
        #endif
    }

    /// Convierte texto libre (dirección pegada, OCR de un sobre…) en una consulta.
    /// Si el modelo no está disponible, devuelve el texto aplanado: el geocoder
    /// de Apple se defiende bien con direcciones completas.
    static func smartQuery(from rawText: String) async -> SmartQuery {
        let fallback = SmartQuery(query: flattened(rawText), countryCode: nil)
        #if canImport(FoundationModels)
        guard isAvailable else { return fallback }
        do {
            let session = LanguageModelSession(instructions: """
                Extraes direcciones postales de texto desordenado (emails, mensajes, \
                texto escaneado de sobres o etiquetas de paquetería). Ignora nombres \
                de personas, teléfonos, referencias de pedido y cualquier otra cosa \
                que no forme parte de la dirección. No inventes datos que no estén \
                en el texto.
                """)
            let parsed = try await session.respond(
                to: "Extrae la dirección de este texto:\n\n\(rawText)",
                generating: ParsedAddress.self
            ).content
            guard let smart = smartQuery(from: parsed) else { return fallback }
            return smart
        } catch {
            return fallback
        }
        #else
        return fallback
        #endif
    }

    /// Resumen breve de la zona, o `nil` si el modelo no está disponible o falla.
    static func areaSummary(for place: PostalPlace) async -> String? {
        #if canImport(FoundationModels)
        guard isAvailable else { return nil }
        let country = Locale.current.localizedString(forRegionCode: place.countryCode) ?? place.countryCode
        var location = [place.neighborhood, place.placeName, place.state, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        if location.isEmpty { location = place.postalCode }
        do {
            let session = LanguageModelSession(instructions: """
                Escribes descripciones breves de lugares para una app de códigos \
                postales. Responde en español, en 2 o 3 frases, sin listas ni \
                títulos. Cuenta qué tipo de zona es y algo característico o \
                interesante. Si no conoces el lugar, describe la región de forma \
                general sin inventar detalles concretos.
                """)
            let response = try await session.respond(
                to: "Describe la zona del código postal \(place.postalCode) en \(location)."
            )
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Privado

    private static func flattened(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    #if canImport(FoundationModels)
    private static func smartQuery(from parsed: ParsedAddress) -> SmartQuery? {
        let street = parsed.street?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let city = parsed.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let code = parsed.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let query: String
        if !street.isEmpty {
            query = city.isEmpty ? street : "\(street), \(city)"
        } else if !code.isEmpty {
            query = code
        } else if !city.isEmpty {
            query = city
        } else {
            return nil
        }

        let country = parsed.countryCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return SmartQuery(query: query, countryCode: country?.count == 2 ? country : nil)
    }
    #endif
}

#if canImport(FoundationModels)
@Generable
private struct ParsedAddress {
    @Guide(description: "Calle con su número si aparece, p. ej. 'Calle Serrano, 21'")
    var street: String?

    @Guide(description: "Ciudad o población")
    var city: String?

    @Guide(description: "Código postal, solo si aparece explícitamente en el texto")
    var postalCode: String?

    @Guide(description: "Código ISO 3166-1 alfa-2 del país si se menciona o se deduce con seguridad, p. ej. 'ES'")
    var countryCode: String?
}
#endif
