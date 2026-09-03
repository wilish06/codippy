//
//  DatasetDownloader.swift
//  codippy
//
//  Descarga datasets de países para uso offline desde la web del proyecto.
//  El manifiesto lista los países disponibles; los ficheros van comprimidos
//  con gzip y se descomprimen con el framework Compression del sistema.
//

import Foundation
import Observation

struct DatasetManifest: Decodable {
    struct Entry: Decodable, Identifiable, Hashable {
        let code: String
        let url: URL
        /// Tamaño del fichero comprimido, para mostrarlo antes de descargar.
        let bytes: Int
        let records: Int
        let updated: String

        var id: String { code }
        var name: String { Locale.current.localizedString(forRegionCode: code) ?? code }
    }

    let entries: [Entry]
}

@Observable
final class DatasetDownloader {
    static let shared = DatasetDownloader()
    static let manifestURL = URL(string: "https://wilish06.github.io/codippy/datasets/manifest.json")!

    private(set) var entries: [DatasetManifest.Entry] = []
    private(set) var isLoadingManifest = false
    private(set) var manifestError: String?
    /// Progreso 0…1 por país mientras se descarga.
    private(set) var progress: [String: Double] = [:]
    private(set) var errors: [String: String] = [:]

    private var tasks: [String: Task<Void, Never>] = [:]

    func loadManifest() async {
        guard entries.isEmpty, !isLoadingManifest else { return }
        isLoadingManifest = true
        defer { isLoadingManifest = false }
        do {
            var request = URLRequest(url: Self.manifestURL)
            request.cachePolicy = .reloadRevalidatingCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw PostalError.badResponse
            }
            entries = try JSONDecoder().decode(DatasetManifest.self, from: data).entries
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            manifestError = nil
        } catch {
            manifestError = (error as? URLError)?.code == .notConnectedToInternet
                ? PostalError.offline.localizedDescription
                : String(localized: "No se ha podido cargar la lista de países.")
        }
    }

    func isDownloading(_ code: String) -> Bool { tasks[code] != nil }

    func download(_ entry: DatasetManifest.Entry) {
        guard tasks[entry.code] == nil else { return }
        errors[entry.code] = nil
        progress[entry.code] = 0
        tasks[entry.code] = Task {
            do {
                try await performDownload(entry)
            } catch is CancellationError {
                // Cancelado por el usuario.
            } catch {
                errors[entry.code] = String(localized: "No se ha podido descargar. Inténtalo de nuevo.")
            }
            progress[entry.code] = nil
            tasks[entry.code] = nil
        }
    }

    func cancel(_ code: String) {
        tasks[code]?.cancel()
    }

    func remove(_ code: String) {
        try? FileManager.default.removeItem(at: DatasetProvider.downloadedFileURL(for: code))
        DatasetProvider.shared.refresh()
    }

    private func performDownload(_ entry: DatasetManifest.Entry) async throws {
        let delegate = ProgressDelegate { [weak self] fraction in
            Task { @MainActor in self?.progress[entry.code] = fraction }
        }
        let (tempURL, response) = try await URLSession.shared.download(from: entry.url, delegate: delegate)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PostalError.badResponse
        }

        let compressed = try Data(contentsOf: tempURL)
        let data = entry.url.pathExtension == "gz" ? try Self.gunzip(compressed) : compressed
        guard !data.isEmpty else { throw PostalError.badResponse }

        let directory = DatasetProvider.downloadsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = DatasetProvider.downloadedFileURL(for: entry.code)
        try data.write(to: destination, options: .atomic)
        DatasetProvider.shared.refresh()
    }

    /// gzip = cabecera de 10 bytes (sin nombre ni extras) + DEFLATE + 8 bytes de cola.
    private static func gunzip(_ data: Data) throws -> Data {
        guard data.count > 18, data[data.startIndex] == 0x1f, data[data.startIndex + 1] == 0x8b else {
            throw PostalError.badResponse
        }
        let flags = data[data.startIndex + 3]
        var offset = 10
        if flags & 0x04 != 0 { // FEXTRA
            let xlen = Int(data[data.startIndex + offset]) | Int(data[data.startIndex + offset + 1]) << 8
            offset += 2 + xlen
        }
        if flags & 0x08 != 0 { // FNAME
            while offset < data.count, data[data.startIndex + offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x10 != 0 { // FCOMMENT
            while offset < data.count, data[data.startIndex + offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x02 != 0 { offset += 2 } // FHCRC
        guard offset < data.count - 8 else { throw PostalError.badResponse }
        let payload = data.subdata(in: (data.startIndex + offset)..<(data.endIndex - 8))
        return try (payload as NSData).decompressed(using: .zlib) as Data
    }
}

/// Recibe el progreso de URLSession en su cola y lo reenvía al actor principal.
private nonisolated final class ProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Double) -> Void

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // El resultado llega por el `await download(from:)`; aquí no hay nada que hacer.
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }
}
