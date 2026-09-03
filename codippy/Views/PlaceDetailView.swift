//
//  PlaceDetailView.swift
//  codippy
//

import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct PlaceDetailView: View {
    let place: PostalPlace

    @Environment(\.modelContext) private var modelContext
    @Environment(PostalRepository.self) private var repository
    @State private var savedEntry: SavedLookup?
    @State private var copied: CopiedItem?
    @State private var neighbors: [(place: PostalPlace, distance: CLLocationDistance)] = []
    @State private var userLocation = UserLocation.shared

    private enum CopiedItem { case code, address }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 14) {
                    if let coordinate = place.coordinate {
                        heroMap(coordinate: coordinate)
                    }
                    detailsCard
                    if let coordinate = place.coordinate {
                        actionButtons(coordinate: coordinate)
                    }
                    if !neighbors.isEmpty {
                        neighborsCard
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
            ToolbarItemGroup(placement: .primaryAction) {
                ShareLink(item: place.fullAddress, subject: Text(place.postalCode)) {
                    Label("Compartir", systemImage: "square.and.arrow.up")
                }
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
        .task {
            saveToHistory()
            neighbors = repository.nearby(to: place)
        }
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
                ForEach(neighbors, id: \.place.id) { neighbor in
                    if let neighborCoordinate = neighbor.place.coordinate {
                        Annotation(neighbor.place.placeName, coordinate: neighborCoordinate, anchor: .center) {
                            NavigationLink(value: neighbor.place) {
                                Text(neighbor.place.postalCode)
                                    .font(.caption2.weight(.bold))
                                    .monospacedDigit()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.thickMaterial, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 240)
            .clipShape(.rect(cornerRadius: 22))
            .allowsHitTesting(true)

            HStack(spacing: 10) {
                CodeChip(code: place.postalCode, large: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(place.placeName)
                        .font(.headline)
                    if let line = place.regionLine {
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                CountryBadge(code: place.countryCode)
            }
            .padding(12)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .padding(10)
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let street = place.street {
                InfoRow(icon: "signpost.right.fill", tint: .brown, label: "Calle", value: street)
            }
            if let neighborhood = place.neighborhood {
                InfoRow(icon: "building.2.fill", tint: .orange, label: "Barrio / distrito", value: neighborhood)
            }
            InfoRow(icon: "mappin.circle.fill", tint: .indigo, label: "Población", value: place.placeName)
            if let province = place.province, !province.isEmpty {
                InfoRow(icon: "map.fill", tint: .purple, label: "Provincia", value: province)
            }
            if !place.state.isEmpty, place.state.caseInsensitiveCompare(place.province ?? "") != .orderedSame {
                InfoRow(icon: "flag.fill", tint: .pink, label: "Región", value: place.state)
            }
            InfoRow(icon: "globe.europe.africa.fill", tint: .blue, label: "País", value: place.countryName)
            if let latitude = place.latitude, let longitude = place.longitude {
                InfoRow(
                    icon: "location.north.circle.fill",
                    tint: .teal,
                    label: "Coordenadas",
                    value: String(format: "%.4f, %.4f", latitude, longitude)
                )
            }
            if let distance = userLocation.distance(to: place) {
                InfoRow(
                    icon: "figure.walk.circle.fill",
                    tint: .green,
                    label: "Distancia desde ti",
                    value: UserLocation.formatted(distance)
                )
            }
        }
        .card()
    }

    private var neighborsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.caption)
                    .foregroundStyle(.indigo)
                Text("Códigos cercanos")
                    .font(.headline)
            }
            VStack(spacing: 0) {
                ForEach(neighbors, id: \.place.id) { neighbor in
                    NavigationLink(value: neighbor.place) {
                        HStack(spacing: 12) {
                            CodeChip(code: neighbor.place.postalCode)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(neighbor.place.placeName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                if let line = neighbor.place.regionLine, line != place.regionLine {
                                    Text(line)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(UserLocation.formatted(neighbor.distance))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if neighbor.place.id != neighbors.last?.place.id {
                        Divider()
                    }
                }
            }
        }
        .card()
    }

    private func actionButtons(coordinate: CLLocationCoordinate2D) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    copy(place.postalCode, as: .code)
                } label: {
                    Label(copied == .code ? "¡Copiado!" : "Copiar código",
                          systemImage: copied == .code ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(copied == .code ? .green : .indigo)

                Button {
                    copy(place.fullAddress, as: .address)
                } label: {
                    Label(copied == .address ? "¡Copiada!" : "Copiar dirección",
                          systemImage: copied == .address ? "checkmark" : "text.alignleft")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(copied == .address ? .green : .indigo)
            }

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

    private func copy(_ text: String, as item: CopiedItem) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
        withAnimation(.snappy) { copied = item }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { if copied == item { copied = nil } }
        }
    }

    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let mapItem = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        mapItem.name = "\(place.postalCode) · \(place.placeName)"
        mapItem.openInMaps()
    }

    private func saveToHistory() {
        let code = place.postalCode
        let country = place.countryCode
        let name = place.placeName
        let descriptor = FetchDescriptor<SavedLookup>(
            predicate: #Predicate { $0.postalCode == code && $0.countryCode == country && $0.placeName == name }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.timestamp = .now
            if existing.neighborhood == nil { existing.neighborhood = place.neighborhood }
            if existing.province == nil { existing.province = place.province }
            savedEntry = existing
        } else {
            let entry = SavedLookup(place: place)
            modelContext.insert(entry)
            savedEntry = entry
        }
    }

    private func toggleFavorite() {
        guard let savedEntry else { return }
        savedEntry.isFavorite.toggle()
        FavoritesSync.publish(from: modelContext)
    }
}

#Preview {
    NavigationStack {
        PlaceDetailView(place: PostalPlace(
            countryCode: "ES", postalCode: "28001", placeName: "Madrid", state: "Comunidad de Madrid",
            latitude: 40.4167, longitude: -3.7033, neighborhood: "Salamanca", province: "Madrid"
        ))
    }
    .environment(PostalRepository())
    .modelContainer(for: SavedLookup.self, inMemory: true)
}
