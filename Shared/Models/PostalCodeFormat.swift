//
//  PostalCodeFormat.swift
//  codippy
//
//  Formato del código postal por país: permite rechazar al instante entradas
//  imposibles ("2800" en España) y explicar cómo son los códigos del país.
//

import Foundation

struct PostalCodeFormat {
    let pattern: String
    let example: String
    /// Longitud mínima (sin espacios ni guiones) para considerar el código completo.
    let minLength: Int

    func matches(_ code: String) -> Bool {
        let compact = Self.compact(code)
        guard let regex = try? Regex("^(?:\(pattern))$").ignoresCase() else { return true }
        return compact.wholeMatch(of: regex) != nil
    }

    func isComplete(_ code: String) -> Bool {
        Self.compact(code).count >= minLength
    }

    static func compact(_ code: String) -> String {
        code.uppercased().filter { !$0.isWhitespace && $0 != "-" }
    }

    static func format(for country: String) -> PostalCodeFormat? {
        formats[country.uppercased()]
    }

    // Patrones sobre el código "compactado" (sin espacios ni guiones, en mayúsculas).
    private static let formats: [String: PostalCodeFormat] = [
        "ES": .init(pattern: #"\d{5}"#, example: "28001", minLength: 5),
        "AD": .init(pattern: #"AD\d{3}"#, example: "AD500", minLength: 5),
        "PT": .init(pattern: #"\d{4}(\d{3})?"#, example: "1000-001", minLength: 4),
        "FR": .init(pattern: #"\d{5}"#, example: "75001", minLength: 5),
        "DE": .init(pattern: #"\d{5}"#, example: "10115", minLength: 5),
        "IT": .init(pattern: #"\d{5}"#, example: "00100", minLength: 5),
        "GB": .init(pattern: #"[A-Z]{1,2}\d[A-Z\d]?(\d[A-Z]{2})?"#, example: "SW1A 1AA", minLength: 2),
        "NL": .init(pattern: #"\d{4}([A-Z]{2})?"#, example: "1011 AB", minLength: 4),
        "BE": .init(pattern: #"\d{4}"#, example: "1000", minLength: 4),
        "CH": .init(pattern: #"\d{4}"#, example: "8001", minLength: 4),
        "AT": .init(pattern: #"\d{4}"#, example: "1010", minLength: 4),
        "PL": .init(pattern: #"\d{5}"#, example: "00-001", minLength: 5),
        "CZ": .init(pattern: #"\d{5}"#, example: "110 00", minLength: 5),
        "SK": .init(pattern: #"\d{5}"#, example: "811 01", minLength: 5),
        "DK": .init(pattern: #"\d{4}"#, example: "1050", minLength: 4),
        "SE": .init(pattern: #"\d{5}"#, example: "111 20", minLength: 5),
        "NO": .init(pattern: #"\d{4}"#, example: "0150", minLength: 4),
        "FI": .init(pattern: #"\d{5}"#, example: "00100", minLength: 5),
        "HU": .init(pattern: #"\d{4}"#, example: "1011", minLength: 4),
        "HR": .init(pattern: #"\d{5}"#, example: "10000", minLength: 5),
        "RO": .init(pattern: #"\d{6}"#, example: "010011", minLength: 6),
        "US": .init(pattern: #"\d{5}(\d{4})?"#, example: "10001", minLength: 5),
        "CA": .init(pattern: #"[A-Z]\d[A-Z](\d[A-Z]\d)?"#, example: "K1A 0B1", minLength: 3),
        "MX": .init(pattern: #"\d{5}"#, example: "06000", minLength: 5),
        "AR": .init(pattern: #"[A-Z]?\d{4}([A-Z]{3})?"#, example: "C1002", minLength: 4),
        "BR": .init(pattern: #"\d{5}(\d{3})?"#, example: "01001-000", minLength: 5),
        "JP": .init(pattern: #"\d{7}"#, example: "100-0001", minLength: 7),
        "IN": .init(pattern: #"\d{6}"#, example: "110001", minLength: 6),
        "AU": .init(pattern: #"\d{4}"#, example: "2000", minLength: 4),
        "NZ": .init(pattern: #"\d{4}"#, example: "6011", minLength: 4),
        "ZA": .init(pattern: #"\d{4}"#, example: "0001", minLength: 4),
        "TR": .init(pattern: #"\d{5}"#, example: "34000", minLength: 5),
        "RU": .init(pattern: #"\d{6}"#, example: "101000", minLength: 6),
    ]
}
