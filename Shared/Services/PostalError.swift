//
//  PostalError.swift
//  codippy
//

import Foundation

enum PostalError: LocalizedError {
    case notFound
    case badResponse
    case offline
    case locationDenied
    case locationUnavailable
    /// El código aún no tiene la longitud del país: no merece la pena buscar.
    case incompleteCode(country: String, example: String)
    /// El código no puede existir en ese país.
    case invalidFormat(country: String, example: String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            String(localized: "No se ha encontrado ningún resultado.")
        case .badResponse:
            String(localized: "El servidor ha devuelto una respuesta inesperada.")
        case .offline:
            String(localized: "Sin conexión. Las búsquedas por calle y en países sin datos offline necesitan internet.")
        case .locationDenied:
            String(localized: "Permiso de localización denegado. Actívalo en Ajustes.")
        case .locationUnavailable:
            String(localized: "No se ha podido obtener tu ubicación.")
        case let .incompleteCode(country, example):
            String(localized: "Sigue escribiendo: los códigos postales de \(country) son como \(example).")
        case let .invalidFormat(country, example):
            String(localized: "Ese código no tiene el formato de \(country) (por ejemplo, \(example)).")
        }
    }

    /// Los avisos de formato son ayuda, no fallos: la interfaz los pinta distinto.
    var isHint: Bool {
        switch self {
        case .incompleteCode, .invalidFormat: true
        default: false
        }
    }
}
