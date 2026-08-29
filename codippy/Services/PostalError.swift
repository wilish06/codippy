//
//  PostalError.swift
//  codippy
//

import Foundation

enum PostalError: LocalizedError {
    case notFound
    case badResponse
    case locationDenied
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .notFound: "No se ha encontrado ningún resultado."
        case .badResponse: "El servidor ha devuelto una respuesta inesperada."
        case .locationDenied: "Permiso de localización denegado. Actívalo en Ajustes."
        case .locationUnavailable: "No se ha podido obtener tu ubicación."
        }
    }
}
