//
//  FavoritesWidget.swift
//  CodippyWidgets
//
//  Tus códigos postales favoritos a un toque. La app los publica en el
//  contenedor compartido cada vez que cambian (FavoritesSync).
//

import SwiftUI
import WidgetKit

struct FavoritesEntry: TimelineEntry {
    let date: Date
    let favorites: [PostalPlace]
}

struct FavoritesProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoritesEntry {
        FavoritesEntry(date: .now, favorites: [.sample])
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoritesEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .never))
    }

    private func current() -> FavoritesEntry {
        FavoritesEntry(date: .now, favorites: FavoritesSync.load())
    }
}

struct FavoritesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: FavoritesSync.widgetKind, provider: FavoritesProvider()) { entry in
            FavoritesView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Favoritos")
        .description("Tus códigos postales guardados como favoritos.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct FavoritesView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FavoritesEntry

    private var limit: Int { family == .systemLarge ? 7 : 3 }

    var body: some View {
        if entry.favorites.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text("Favoritos").font(.headline)
                }
                Text("Marca códigos postales con la estrella en Codippy y aparecerán aquí.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(AppRouter.searchURL(query: "", country: nil))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text("Favoritos").font(.headline)
                    Spacer()
                    Text("\(entry.favorites.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                ForEach(entry.favorites.prefix(limit)) { place in
                    Link(destination: AppRouter.searchURL(for: place)) {
                        HStack(spacing: 10) {
                            CodeChip(code: place.postalCode)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(place.street ?? place.placeName)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                if let line = place.street != nil ? place.placeName : place.regionLine {
                                    Text(line)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            CountryBadge(code: place.countryCode)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
