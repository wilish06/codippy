//
//  SmartSearchView.swift
//  codippy
//
//  Pega cualquier texto con una dirección (un email, un WhatsApp, una firma…)
//  y la IA on-device extrae la dirección y lanza la búsqueda.
//

import SwiftUI

struct SmartSearchView: View {
    /// Texto que llega ya escrito (extensión de compartir, servicio de macOS, URL).
    var initialText: String? = nil
    let onResult: (SmartQuery) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isParsing = false
    @FocusState private var editorFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 14) {
                    editor
                    if IntelligenceService.isAvailable {
                        Label("La dirección se extrae con IA en tu dispositivo, sin conexión.", systemImage: "lock.shield")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("IA no disponible en este dispositivo; se buscará el texto tal cual.", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    searchButton
                }
                .padding()
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Pegar dirección")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onAppear {
                if let initialText, text.isEmpty {
                    text = initialText
                }
                if let demo = UserDefaults.standard.string(forKey: "demoSmartText"), text.isEmpty {
                    text = demo
                } else {
                    editorFocused = true
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 380)
        #endif
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused($editorFocused)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 160, maxHeight: 240)
                .background(.regularMaterial, in: .rect(cornerRadius: 18))

            if text.isEmpty {
                Text("Pega aquí un texto con una dirección…\n\n\"Te lo mando a Calle Serrano 21,\n3ºB, Madrid. ¡Gracias!\"")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(18)
                    .allowsHitTesting(false)
            }

            pasteButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(10)
        }
        .frame(maxHeight: 260)
    }

    private var pasteButton: some View {
        Button {
            #if os(macOS)
            if let pasted = NSPasteboard.general.string(forType: .string) {
                text = pasted
            }
            #else
            if let pasted = UIPasteboard.general.string {
                text = pasted
            }
            #endif
        } label: {
            Label("Pegar", systemImage: "doc.on.clipboard")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(.indigo)
    }

    private var searchButton: some View {
        Button {
            Task { await search() }
        } label: {
            HStack {
                if isParsing {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analizando…")
                } else {
                    Label("Buscar con IA", systemImage: "sparkle.magnifyingglass")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(.indigo)
        .disabled(isParsing || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func search() async {
        isParsing = true
        defer { isParsing = false }
        let smart = await IntelligenceService.smartQuery(from: text)
        onResult(smart)
        dismiss()
    }
}

#Preview {
    SmartSearchView { _ in }
}
