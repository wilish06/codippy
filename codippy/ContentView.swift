//
//  ContentView.swift
//  codippy
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Buscar", systemImage: "magnifyingglass") {
                SearchView()
            }
            Tab("Historial", systemImage: "clock") {
                HistoryView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(PostalRepository())
        .modelContainer(for: SavedLookup.self, inMemory: true)
}
