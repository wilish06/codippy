//
//  ScanAddressView.swift
//  codippy
//
//  Escanea un sobre, etiqueta de paquete o captura de pantalla: OCR con Vision
//  (y cámara en vivo con VisionKit en iPhone/iPad), y la IA on-device extrae la
//  dirección para lanzar la búsqueda.
//

import PhotosUI
import SwiftUI
import Vision

#if os(iOS)
import VisionKit
#endif

struct ScanAddressView: View {
    let onResult: (SmartQuery) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var capturedText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 0) {
                    scannerArea
                    controls
                }
            }
            .navigationTitle("Escanear dirección")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onChange(of: photoItem) {
                guard let photoItem else { return }
                Task { await recognizeText(from: photoItem) }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 420)
        #endif
    }

    // MARK: - Zona de escaneo

    @ViewBuilder
    private var scannerArea: some View {
        #if os(iOS)
        if LiveTextScanner.isSupported {
            ZStack(alignment: .bottom) {
                LiveTextScanner { tapped in
                    appendText(tapped)
                }
                .clipShape(.rect(cornerRadius: 24))
                Text("Toca el texto de la dirección para capturarlo")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 12)
            }
            .padding(.horizontal)
        } else {
            photoOnlyPlaceholder
        }
        #else
        photoOnlyPlaceholder
        #endif
    }

    private var photoOnlyPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.indigo)
            Text("Elige una foto de un sobre, etiqueta o captura con una dirección y se leerá automáticamente.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .card()
        .padding(.horizontal)
    }

    // MARK: - Controles

    private var controls: some View {
        VStack(spacing: 12) {
            if !capturedText.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "text.quote")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                        .padding(.top, 2)
                    Text(capturedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                    Spacer(minLength: 0)
                    Button {
                        capturedText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .card()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Foto", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.indigo)

                Button {
                    Task { await search() }
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Buscar con IA", systemImage: "sparkle.magnifyingglass")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(capturedText.isEmpty || isProcessing)
            }
            .controlSize(.large)
            .buttonBorderShape(.capsule)
        }
        .padding()
    }

    // MARK: - Acciones

    private func appendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !capturedText.contains(trimmed) else { return }
        capturedText = capturedText.isEmpty ? trimmed : "\(capturedText)\n\(trimmed)"
    }

    /// OCR de la imagen elegida con Vision.
    private func recognizeText(from item: PhotosPickerItem) async {
        isProcessing = true
        defer {
            isProcessing = false
            photoItem = nil
        }
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PostalError.notFound
            }
            var request = RecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let observations = try await request.perform(on: data)
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            guard !lines.isEmpty else {
                errorMessage = String(localized: "No se ha encontrado texto en la imagen.")
                return
            }
            capturedText = lines.joined(separator: "\n")
        } catch {
            errorMessage = String(localized: "No se ha podido leer la imagen.")
        }
    }

    private func search() async {
        isProcessing = true
        defer { isProcessing = false }
        let smart = await IntelligenceService.smartQuery(from: capturedText)
        onResult(smart)
        dismiss()
    }
}

// MARK: - Cámara en vivo (solo iPhone/iPad)

#if os(iOS)
/// Escáner de texto en vivo de VisionKit; el usuario toca el texto reconocido.
struct LiveTextScanner: UIViewControllerRepresentable {
    let onTap: (String) -> Void

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onTap: (String) -> Void

        init(onTap: @escaping (String) -> Void) {
            self.onTap = onTap
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let text) = item {
                onTap(text.transcript)
            }
        }
    }
}
#endif

#Preview {
    ScanAddressView { _ in }
}
