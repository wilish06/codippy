//
//  PlaceDetailView.swift
//  codippy
//

import MapKit
import SwiftData
import SwiftUI

struct PlaceDetailView: View {
    let place: PostalPlace

    @Environment(\.modelContext) private var modelContext
    @State private var savedEntry: SavedLookup?
    @State private var justCopied = false
    @State private var aiSummary: String?
    @State private var isGeneratingSummary = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 14) {
                    if let coordinate = place.coordinate {
                        heroMap(coordinate: coordinate)
                    }
                    detailsCard
                    if IntelligenceService.isAvailable {
                        aiSummaryCard
                    }
                    if let coordinate = place.coordinate {
                        actionButtons(coordinate: coordinate)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(place.postalCode)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    toggleFavorite()
                } label: {
                    Label(
                        isFavorite ? "Quitar de favoritos" : "Añadir a favoritos",
                        systemImage: isFavorite ? "star.fill" : "star"
                    )
                    .symbolEffect(.bounce, value: isFavorite)
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                }
            }
        }
        .task { saveToHistory() }
        .task { await generateSummary() }
    }

    // MARK: - Secciones

    private func heroMap(coordinate: CLLocationCoordinate2D) -> some View {
        ZStack(alignment: .bottomLeading) {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            ))) {
                Marker("\(place.postalCode) · \(place.placeName)", coordinate: coordinate)
                    .tint(.indigo)
            }
            .frame(height: 320)
            .clipShape(.rect(cornerRadius: 24))

            HStack(spacing: 10) {
                CodeChip(code: place.postalCode, large: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(place.street ?? place.placeName)
                        .font(.subheadline.weight(.semibold))
                    if let neighborhood = place.neighborhood {
                        Text(neighborhood)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.trailing, 4)
            }
            .padding(8)
            .background(.regularMaterial, in: .rect(cornerRadius: 18))
            .padding(12)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let street = place.street {
                InfoRow(icon: "signpost.right.fill", tint: .orange, label: "Calle", value: street)
            }
            if let neighborhood = place.neighborhood {
                InfoRow(icon: "building.2.fill", tint: .purple, label: "Barrio / Distrito", value: neighborhood)
            }
            InfoRow(icon: "mappin.circle.fill", tint: .red, label: "Población", value: place.placeName)
            if !place.state.isEmpty {
                InfoRow(icon: "map.fill", tint: .green, label: "Provincia / Estado", value: place.state)
            }
            InfoRow(
                icon: "globe.europe.africa.fill",
                tint: .blue,
                label: "País",
                value: "\(Locale.current.localizedString(forRegionCode: place.countryCode) ?? place.countryCode) (\(place.countryCode.uppercased()))"
            )
            if let latitude = place.latitude, let longitude = place.longitude {
                InfoRow(
                    icon: "location.north.circle.fill",
                    tint: .teal,
                    label: "Coordenadas",
                    value: String(format: "%.4f, %.4f", latitude, longitude)
                )
            }
        }
        .card()
    }

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.indigo)
                Text("Sobre esta zona")
                    .font(.headline)
            }

            if let aiSummary {
                Text(aiSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Generado con IA en tu dispositivo · puede contener errores")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if isGeneratingSummary {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Escribiendo…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No se ha podido generar la descripción.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func actionButtons(coordinate: CLLocationCoordinate2D) -> some View {
        HStack(spacing: 10) {
            Button {
                copyCode()
            } label: {
                Label(justCopied ? "¡Copiado!" : "Copiar código", systemImage: justCopied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(justCopied ? .green : .indigo)

            Button {
                openInMaps(coordinate: coordinate)
            } label: {
                Label("Abrir en Mapas", systemImage: "map.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .controlSize(.large)
        .buttonBorderShape(.capsule)
    }

    // MARK: - Acciones

    private var isFavorite: Bool { savedEntry?.isFavorite ?? false }

    private func generateSummary() async {
        guard IntelligenceService.isAvailable, aiSummary == nil else { return }
        isGeneratingSummary = true
        defer { isGeneratingSummary = false }
        aiSummary = await IntelligenceService.areaSummary(for: place)
    }

    private func copyCode() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(place.postalCode, forType: .string)
        #else
        UIPasteboard.general.string = place.postalCode
        #endif
        withAnimation(.snappy) { justCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy) { justCopied = false }
        }
    }

    private func saveToHistory() {
        let entry = existingEntry() ?? {
            let new = SavedLookup(place: place)
            modelContext.insert(new)
            return new
        }()
        entry.timestamp = .now
        savedEntry = entry
    }

    private func toggleFavorite() {
        saveToHistory()
        withAnimation(.snappy) {
            savedEntry?.isFavorite.toggle()
        }
    }

    private func existingEntry() -> SavedLookup? {
        if let savedEntry { return savedEntry }
        let country = place.countryCode
        let code = place.postalCode
        let name = place.placeName
        let descriptor = FetchDescriptor<SavedLookup>(
            predicate: #Predicate { $0.countryCode == country && $0.postalCode == code && $0.placeName == name }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        item.name = "\(place.postalCode) \(place.placeName)"
        item.openInMaps()
    }
}

#Preview {
    NavigationStack {
        PlaceDetailView(place: PostalPlace(
            countryCode: "ES",
            postalCode: "28001",
            placeName: "Madrid",
            state: "Madrid",
            latitude: 40.4258,
            longitude: -3.6906,
            neighborhood: "Salamanca"
        ))
    }
    .modelContainer(for: SavedLookup.self, inMemory: true)
}
