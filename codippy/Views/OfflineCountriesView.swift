//
//  OfflineCountriesView.swift
//  codippy
//
//  Gestión de datasets por país para buscar sin conexión.
//

import SwiftUI

struct OfflineCountriesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var downloader = DatasetDownloader.shared
    @State private var datasets = DatasetProvider.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Los países con datos descargados se buscan al instante y sin internet. Los datos son de GeoNames (CC BY 4.0).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !datasets.bundledCountries.isEmpty {
                    Section("Incluidos en la app") {
                        ForEach(datasets.bundledCountries.sorted(by: Self.byName), id: \.self) { code in
                            HStack {
                                CountryBadge(code: code)
                                Text(Self.name(code))
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                Section("Disponibles para descargar") {
                    if downloader.isLoadingManifest && downloader.entries.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Cargando lista…").foregroundStyle(.secondary)
                        }
                    } else if let error = downloader.manifestError, downloader.entries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error).foregroundStyle(.secondary)
                            Button("Reintentar") { Task { await downloader.loadManifest() } }
                        }
                    } else {
                        ForEach(downloadable) { entry in
                            row(for: entry)
                        }
                    }
                }
            }
            .navigationTitle("Países sin conexión")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") { dismiss() }
                }
            }
            .task { await downloader.loadManifest() }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }

    private var downloadable: [DatasetManifest.Entry] {
        downloader.entries.filter { !datasets.bundledCountries.contains($0.code) }
    }

    @ViewBuilder
    private func row(for entry: DatasetManifest.Entry) -> some View {
        let isDownloaded = datasets.downloadedCountries.contains(entry.code)
        HStack(spacing: 12) {
            CountryBadge(code: entry.code)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                Text(subtitle(for: entry, downloaded: isDownloaded))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let progress = downloader.progress[entry.code] {
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                    Button {
                        downloader.cancel(entry.code)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            } else if isDownloaded {
                Button(role: .destructive) {
                    downloader.remove(entry.code)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            } else {
                Button {
                    downloader.download(entry)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .tint(.indigo)
            }
        }
    }

    private func subtitle(for entry: DatasetManifest.Entry, downloaded: Bool) -> String {
        if let error = downloader.errors[entry.code] { return error }
        let size = ByteCountFormatter.string(fromByteCount: Int64(entry.bytes), countStyle: .file)
        let records = entry.records.formatted()
        return downloaded
            ? String(localized: "Descargado · \(records) códigos")
            : String(localized: "\(size) · \(records) códigos")
    }

    private static func name(_ code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    private static func byName(_ a: String, _ b: String) -> Bool {
        name(a).localizedStandardCompare(name(b)) == .orderedAscending
    }
}

#Preview {
    OfflineCountriesView()
}
