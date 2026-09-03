//
//  SearchCompleterService.swift
//  codippy
//
//  Sugerencias mientras se escribe (autocompletado de MapKit), para cuando
//  el usuario no pone el nombre exacto.
//

import Foundation
import MapKit
import Observation

@Observable
final class SearchCompleterService: NSObject, MKLocalSearchCompleterDelegate {
    struct Suggestion: Identifiable, Hashable {
        let title: String
        let subtitle: String

        var id: String { "\(title)|\(subtitle)" }
        var fullText: String { subtitle.isEmpty ? title : "\(title), \(subtitle)" }
    }

    private(set) var suggestions: [Suggestion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(query: String) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            completer.cancel()
            suggestions = []
            return
        }
        completer.queryFragment = text
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.prefix(6).map {
            Suggestion(title: $0.title, subtitle: $0.subtitle)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
