//
//  codippyApp.swift
//  codippy
//

import SwiftData
import SwiftUI

@main
struct codippyApp: App {
    @State private var repository = PostalRepository()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(repository)
        }
        .modelContainer(for: SavedLookup.self)
    }
}
