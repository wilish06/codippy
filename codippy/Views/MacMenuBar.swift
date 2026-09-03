//
//  MacMenuBar.swift
//  codippy
//
//  Solo macOS: búsqueda rápida desde la barra de menús, ajustes y el servicio
//  "Buscar código postal con Codippy" del menú contextual del sistema.
//

#if os(macOS)
import AppKit
import SwiftUI

struct MenuBarSearchView: View {
    @Environment(PostalRepository.self) private var repository
    @Environment(\.openURL) private var openURL
    @AppStorage("selectedCountry") private var selectedCountry = "ES"
    @State private var query = ""
    @State private var results: [PostalPlace] = []
    @State private var message: String?
    @State private var isSearching = false
    @State private var copiedID: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Código postal, ciudad o calle", text: $query)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { Task { await search() } }
                Picker("País", selection: $selectedCountry) {
                    ForEach(repository.countries) { country in
                        Text(country.code).tag(country.code)
                    }
                }
                .labelsHidden()
                .frame(width: 70)
            }
            .padding(10)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))

            if isSearching {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Buscando…").foregroundStyle(.secondary)
                }
                .font(.callout)
            } else if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if !results.isEmpty {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(results.prefix(12)) { place in
                            resultRow(place)
                        }
                    }
                }
                .frame(maxHeight: 260)
            } else {
                Text("Escribe y pulsa Intro. Clic en un resultado para copiar el código.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("Abrir Codippy") {
                    openURL(AppRouter.searchURL(query: query, country: selectedCountry))
                    NSApp.activate()
                }
                Spacer()
                SettingsLink { Text("Ajustes…") }
                Button("Salir") { NSApp.terminate(nil) }
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 340)
        .task(id: query) {
            guard query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            results = []
            message = nil
        }
        .onAppear { focused = true }
    }

    private func resultRow(_ place: PostalPlace) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(place.postalCode, forType: .string)
            copiedID = place.id
        } label: {
            HStack(spacing: 10) {
                CodeChip(code: place.postalCode)
                VStack(alignment: .leading, spacing: 1) {
                    Text(place.street ?? place.placeName)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    if let line = place.street != nil ? place.placeName : place.regionLine {
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: copiedID == place.id ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(copiedID == place.id ? .green : .secondary)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await repository.search(text, country: selectedCountry)
            message = nil
        } catch {
            results = []
            message = error.localizedDescription
        }
    }
}

struct SettingsView: View {
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some View {
        Form {
            Toggle("Mostrar Codippy en la barra de menús", isOn: $showMenuBarExtra)
            Text("Selecciona una dirección en cualquier app y usa el menú Servicios para buscarla con Codippy.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Proveedor del servicio de sistema declarado en Info.plist (NSServices).
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    @objc func lookupPostalCode(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            error.pointee = NSString(string: String(localized: "No hay texto seleccionado."))
            return
        }
        AppRouter.shared.go(.smartText(text))
        NSApp.activate()
    }
}
#endif
