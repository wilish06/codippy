//
//  ShareViewController.swift
//  CodippyShare
//
//  Extensión de compartir: recibe texto seleccionado en cualquier app, extrae la
//  dirección y muestra los códigos postales sin salir de donde estabas.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let host = UIHostingController(rootView: ShareView(
            loadText: { [weak self] in await self?.incomingText() ?? "" },
            openInApp: { [weak self] url in self?.openHostApp(url) },
            finish: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        ))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }

    /// Junta todo el texto plano que venga en la petición.
    private func incomingText() async -> String {
        var pieces: [String] = []
        for item in extensionContext?.inputItems as? [NSExtensionItem] ?? [] {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) {
                    if let text = loaded as? String {
                        pieces.append(text)
                    } else if let data = loaded as? Data, let text = String(data: data, encoding: .utf8) {
                        pieces.append(text)
                    } else if let url = loaded as? URL, let text = try? String(contentsOf: url, encoding: .utf8) {
                        pieces.append(text)
                    }
                }
            }
            if pieces.isEmpty, let text = item.attributedContentText?.string {
                pieces.append(text)
            }
        }
        return pieces.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Las extensiones no pueden abrir apps directamente; se sube por la cadena
    /// de respondedores hasta UIApplication.
    private func openHostApp(_ url: URL) {
        var responder: UIResponder? = self
        let selector = NSSelectorFromString("openURL:")
        while let current = responder {
            if current.responds(to: selector), !(current is UIViewController) {
                current.perform(selector, with: url)
                break
            }
            responder = current.next
        }
        extensionContext?.completeRequest(returningItems: nil)
    }
}
