//
//  BundledDatasetProvider.swift
//  codippy
//
//  Búsqueda offline sobre datasets empaquetados en el bundle de la app.
//
//  Para añadir un país, arrastra al proyecto (carpeta Datasets) un fichero
//  llamado `postalcodes_XX.tsv|csv|txt`, donde XX es el código ISO del país:
//   - Separado por tabuladores: formato GeoNames (download.geonames.org/export/zip/),
//     columnas: país, código postal, población, provincia, ... , latitud, longitud.
//   - Separado por comas: cabecera `country,postal_code,place,state,latitude,longitude`.
//

import Foundation

final class BundledDatasetProvider {
    private var cache: [String: [PostalPlace]] = [:]
    private var fileURLs: [String: URL] = [:]

    /// Códigos ISO de país con dataset empaquetado.
    let availableCountries: [String]

    init(bundle: Bundle = .main) {
        var urls: [String: URL] = [:]
        for ext in ["tsv", "csv", "txt"] {
            for url in bundle.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [] {
                let name = url.deletingPathExtension().lastPathComponent
                guard name.lowercased().hasPrefix("postalcodes_") else { continue }
                let country = String(name.dropFirst("postalcodes_".count)).uppercased()
                guard country.count == 2 else { continue }
                urls[country] = url
            }
        }
        fileURLs = urls
        availableCountries = urls.keys.sorted()
    }

    func hasDataset(for country: String) -> Bool {
        fileURLs[country.uppercased()] != nil
    }

    func lookup(code: String, country: String) throws -> [PostalPlace] {
        let normalized = Self.normalize(code)
        let matches = try places(for: country).filter { Self.normalize($0.postalCode) == normalized }
        guard !matches.isEmpty else { throw PostalError.notFound }
        return matches
    }

    func search(place: String, country: String) throws -> [PostalPlace] {
        let needle = Self.normalize(place)
        let matches = try places(for: country)
            .filter { Self.normalize($0.placeName).contains(needle) }
            .prefix(50)
        guard !matches.isEmpty else { throw PostalError.notFound }
        return Array(matches)
    }

    private func places(for country: String) throws -> [PostalPlace] {
        let key = country.uppercased()
        if let cached = cache[key] { return cached }
        guard let url = fileURLs[key] else { throw PostalError.notFound }
        let contents = try String(contentsOf: url, encoding: .utf8)
        let parsed = Self.parse(contents, country: key)
        cache[key] = parsed
        return parsed
    }

    private static func parse(_ contents: String, country: String) -> [PostalPlace] {
        var places: [PostalPlace] = []
        contents.enumerateLines { line, _ in
            guard !line.isEmpty else { return }
            if line.contains("\t") {
                // Formato GeoNames: 12 columnas separadas por tabulador.
                let cols = line.components(separatedBy: "\t")
                guard cols.count >= 11, let lat = Double(cols[9]), let lon = Double(cols[10]) else { return }
                places.append(PostalPlace(
                    countryCode: cols[0].isEmpty ? country : cols[0],
                    postalCode: cols[1],
                    placeName: cols[2],
                    state: cols[3],
                    latitude: lat,
                    longitude: lon
                ))
            } else {
                // CSV simple: country,postal_code,place,state,latitude,longitude
                let cols = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard cols.count >= 6, let lat = Double(cols[4]), let lon = Double(cols[5]) else { return }
                places.append(PostalPlace(
                    countryCode: cols[0].isEmpty ? country : cols[0],
                    postalCode: cols[1],
                    placeName: cols[2],
                    state: cols[3],
                    latitude: lat,
                    longitude: lon
                ))
            }
        }
        return places
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: " ", with: "")
    }
}
