//
//  DatasetProvider.swift
//  codippy
//
//  Búsqueda 100% offline sobre datasets de códigos postales, que pueden venir
//  empaquetados en la app (postalcodes_<ISO2>.tsv) o descargados por el usuario.
//  Formatos: GeoNames (TSV de 12 columnas) o CSV simple
//  (country,postal_code,place,state,latitude,longitude).
//

import CoreLocation
import Foundation
import Observation

@Observable
final class DatasetProvider {
    static let shared = DatasetProvider()

    /// Países con dataset disponible (empaquetado o descargado), en ISO2.
    private(set) var availableCountries: Set<String> = []
    private(set) var bundledCountries: Set<String> = []
    private(set) var downloadedCountries: Set<String> = []

    private var fileURLs: [String: URL] = [:]
    private var cache: [String: [PostalPlace]] = [:]

    init() {
        refresh()
    }

    /// Carpeta donde se guardan los datasets descargados por el usuario.
    static var downloadsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "Datasets", directoryHint: .isDirectory)
    }

    static func downloadedFileURL(for country: String) -> URL {
        downloadsDirectory.appending(path: "postalcodes_\(country.uppercased()).tsv")
    }

    /// Vuelve a escanear bundle y descargas. Llamar tras descargar o borrar.
    func refresh() {
        var urls: [String: URL] = [:]
        var bundled: Set<String> = []
        var downloaded: Set<String> = []

        for bundle in Self.resourceBundles {
            for ext in ["tsv", "csv", "txt"] {
                for url in bundle.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [] {
                    guard let code = Self.countryCode(fromFileName: url.deletingPathExtension().lastPathComponent) else { continue }
                    urls[code] = url
                    bundled.insert(code)
                }
            }
        }

        let files = (try? FileManager.default.contentsOfDirectory(
            at: Self.downloadsDirectory, includingPropertiesForKeys: nil
        )) ?? []
        for url in files where ["tsv", "csv", "txt"].contains(url.pathExtension) {
            guard let code = Self.countryCode(fromFileName: url.deletingPathExtension().lastPathComponent) else { continue }
            // Un dataset descargado sustituye al empaquetado (será más reciente).
            urls[code] = url
            downloaded.insert(code)
        }

        fileURLs = urls
        bundledCountries = bundled
        downloadedCountries = downloaded
        availableCountries = Set(urls.keys)
        cache.removeAll()
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
        let all = try places(for: country)
        // Primero las poblaciones que empiezan por lo escrito; luego las que lo contienen.
        let starts = all.filter { Self.normalize($0.placeName).hasPrefix(needle) }
        let contains = starts.count >= 50 ? [] : all.filter {
            let name = Self.normalize($0.placeName)
            return !name.hasPrefix(needle) && name.contains(needle)
        }
        let matches = Array((starts + contains).prefix(50))
        guard !matches.isEmpty else { throw PostalError.notFound }
        return matches
    }

    /// Códigos postales distintos más cercanos a un lugar, con su distancia en metros.
    func nearby(to place: PostalPlace, limit: Int = 8, maxDistance: CLLocationDistance = 30_000) -> [(place: PostalPlace, distance: CLLocationDistance)] {
        guard let origin = place.location, hasDataset(for: place.countryCode),
              let all = try? places(for: place.countryCode) else { return [] }
        var best: [String: (place: PostalPlace, distance: CLLocationDistance)] = [:]
        for candidate in all where candidate.postalCode != place.postalCode {
            guard let location = candidate.location else { continue }
            // Filtro barato antes de calcular la distancia real.
            guard abs(location.coordinate.latitude - origin.coordinate.latitude) < 0.5,
                  abs(location.coordinate.longitude - origin.coordinate.longitude) < 0.7 else { continue }
            let distance = origin.distance(from: location)
            guard distance <= maxDistance else { continue }
            if let existing = best[candidate.postalCode], existing.distance <= distance { continue }
            best[candidate.postalCode] = (candidate, distance)
        }
        return best.values.sorted { $0.distance < $1.distance }.prefix(limit).map { $0 }
    }

    // MARK: - Privado

    /// Bundle propio y, si somos una extensión, el de la app contenedora
    /// (para no duplicar los datasets en cada extensión).
    private static var resourceBundles: [Bundle] {
        var bundles = [Bundle.main]
        if Bundle.main.bundleURL.pathExtension == "appex" {
            var url = Bundle.main.bundleURL
            for _ in 0..<4 {
                url = url.deletingLastPathComponent()
                if url.pathExtension == "app", let host = Bundle(url: url) {
                    bundles.append(host)
                    break
                }
            }
        }
        return bundles
    }

    private static func countryCode(fromFileName name: String) -> String? {
        let prefix = "postalcodes_"
        guard name.lowercased().hasPrefix(prefix) else { return nil }
        let code = String(name.dropFirst(prefix.count)).uppercased()
        guard code.count == 2, code.allSatisfy(\.isLetter) else { return nil }
        return code
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

    static func parse(_ contents: String, country: String) -> [PostalPlace] {
        var places: [PostalPlace] = []
        contents.enumerateLines { line, _ in
            guard !line.isEmpty else { return }
            if line.contains("\t") {
                // Formato GeoNames: 12 columnas separadas por tabulador.
                let cols = line.components(separatedBy: "\t")
                guard cols.count >= 11, let lat = Double(cols[9]), let lon = Double(cols[10]) else { return }
                let province = cols[5].trimmingCharacters(in: .whitespaces)
                places.append(PostalPlace(
                    countryCode: cols[0].isEmpty ? country : cols[0],
                    postalCode: cols[1],
                    placeName: cols[2],
                    state: cols[3],
                    latitude: lat,
                    longitude: lon,
                    province: province.isEmpty ? nil : province
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
