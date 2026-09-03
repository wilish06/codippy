//
//  ShareView.swift
//  CodippyShare
//

import SwiftUI

struct ShareView: View {
    let loadText: () async -> String
    let openInApp: (URL) -> Void
    let finish: () -> Void

    private enum Phase: Equatable {
        case loading
        case results([PostalPlace])
        case empty(String)
    }

    @State private var phase: Phase = .loading
    @State private var sourceText = ""
    @State private var query = ""
    @State private var country = Locale.current.region?.identifier ?? "ES"
    @State private var copiedID: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                content
            }
            .navigationTitle("Codippy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { finish() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Abrir en Codippy") {
                        let url = query.isEmpty
                            ? AppRouter.smartURL(text: sourceText)
                            : AppRouter.searchURL(query: query, country: country)
                        openInApp(url)
                    }
                    .disabled(sourceText.isEmpty)
                }
            }
        }
        .task { await run() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text("Leyendo la dirección…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case let .empty(message):
            VStack(spacing: 10) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !sourceText.isEmpty {
                    Text("Puedes abrirla en Codippy para revisarla a mano.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(24)
        case let .results(places):
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !query.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text(query)
                            Spacer()
                            CountryBadge(code: country)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                    }
                    ForEach(places.prefix(20)) { place in
                        row(place)
                    }
                    Text("Toca un resultado para copiar el código.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding()
            }
        }
    }

    private func row(_ place: PostalPlace) -> some View {
        Button {
            UIPasteboard.general.string = place.postalCode
            withAnimation(.snappy) { copiedID = place.id }
        } label: {
            HStack(spacing: 12) {
                PlaceRowCompact(place: place)
                Image(systemName: copiedID == place.id ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(copiedID == place.id ? .green : .secondary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private func run() async {
        sourceText = await loadText()
        guard !sourceText.isEmpty else {
            phase = .empty(String(localized: "No ha llegado ningún texto."))
            return
        }
        let smart = await IntelligenceService.smartQuery(from: sourceText)
        query = smart.query
        if let code = smart.countryCode, PostalRepository.onlineCountries.contains(code) {
            country = code
        } else if !PostalRepository.onlineCountries.contains(country) {
            country = "ES"
        }
        do {
            let found = try await PostalRepository().search(query, country: country)
            phase = found.isEmpty ? .empty(PostalError.notFound.localizedDescription) : .results(found)
        } catch {
            phase = .empty(error.localizedDescription)
        }
    }
}

/// Fila de resultado sin dependencias de la app principal.
struct PlaceRowCompact: View {
    let place: PostalPlace

    var body: some View {
        HStack(spacing: 12) {
            CodeChip(code: place.postalCode)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.street ?? place.placeName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                if let subtitle = place.street != nil ? place.placeName : place.regionLine {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            CountryBadge(code: place.countryCode)
        }
    }
}
