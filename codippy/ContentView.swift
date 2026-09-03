//
//  ContentView.swift
//  codippy
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var router = AppRouter.shared
    #if os(iOS)
    @State private var showSplash = !UserDefaults.standard.bool(forKey: "demoNoSplash")
    #endif

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Buscar", systemImage: "magnifyingglass", value: AppRouter.Tab.search) {
                SearchView()
            }
            Tab("Historial", systemImage: "clock", value: AppRouter.Tab.history) {
                HistoryView()
            }
        }
        #if os(iOS)
        .overlay {
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.08)))
                .zIndex(1)
            }
        }
        #endif
        .onOpenURL { url in
            router.handle(url)
        }
        .task {
            FavoritesSync.publish(from: modelContext)
            _ = await LocationService().currentLocationIfAuthorized()
        }
    }
}

#Preview {
    ContentView()
        .environment(PostalRepository())
        .modelContainer(for: SavedLookup.self, inMemory: true)
}
