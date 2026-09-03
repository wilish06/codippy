//
//  FavoritesSync.swift
//  codippy
//
//  Publica los favoritos en el contenedor compartido con el widget (App Group)
//  y le pide que se refresque. Solo en iOS, donde vive el widget.
//

import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

enum FavoritesSync {
    static let appGroup = "group.com.wilish.codippy"
    static let key = "favorites"
    static let widgetKind = "FavoritesWidget"

    static func publish(from context: ModelContext) {
        #if os(iOS)
        let descriptor = FetchDescriptor<SavedLookup>(
            predicate: #Predicate { $0.isFavorite },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let favorites = (try? context.fetch(descriptor))?.map(\.place) ?? []
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(favorites) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        #endif
    }

    /// Lectura desde el widget.
    static func load() -> [PostalPlace] {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PostalPlace].self, from: data)) ?? []
    }
}
