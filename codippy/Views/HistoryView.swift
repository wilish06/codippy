//
//  HistoryView.swift
//  codippy
//

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedLookup.timestamp, order: .reverse) private var entries: [SavedLookup]

    private var favorites: [SavedLookup] { entries.filter(\.isFavorite) }
    private var recents: [SavedLookup] { entries.filter { !$0.isFavorite } }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if entries.isEmpty {
                    emptyState
                } else {
                    List {
                        if !favorites.isEmpty {
                            section(title: "Favoritos", icon: "star.fill", tint: .yellow, items: favorites)
                        }
                        if !recents.isEmpty {
                            section(title: "Recientes", icon: "clock.fill", tint: .indigo, items: recents)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Historial")
            .navigationDestination(for: PostalPlace.self) { place in
                PlaceDetailView(place: place)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "clock")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(Theme.accent, in: Circle())
            VStack(spacing: 6) {
                Text("Todavía nada")
                    .font(.title3.weight(.semibold))
                Text("Tus búsquedas y favoritos aparecerán aquí.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func section(title: String, icon: String, tint: Color, items: [SavedLookup]) -> some View {
        Section {
            ForEach(items) { entry in
                NavigationLink(value: entry.place) {
                    PlaceRow(place: entry.place)
                }
                .listRowBackground(
                    Rectangle().fill(.regularMaterial)
                )
            }
            .onDelete { delete(from: items, at: $0) }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .textCase(nil)
        }
    }

    private func delete(from list: [SavedLookup], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(list[index])
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: SavedLookup.self, inMemory: true)
}
