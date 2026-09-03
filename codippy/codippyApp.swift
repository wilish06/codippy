//
//  codippyApp.swift
//  codippy
//

import SwiftData
import SwiftUI

@main
struct codippyApp: App {
    @State private var repository = PostalRepository()
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(repository)
        }
        .modelContainer(for: SavedLookup.self)

        #if os(macOS)
        MenuBarExtra("Codippy", systemImage: "mappin.and.ellipse", isInserted: $showMenuBarExtra) {
            MenuBarSearchView()
                .environment(repository)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
        #endif
    }
}
