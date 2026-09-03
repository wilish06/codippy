//
//  CurrentPostalCodeWidget.swift
//  CodippyWidgets
//
//  Código postal de donde estás ahora. Usa la ubicación que la app ya tiene
//  autorizada; si no la hay, invita a abrir la app.
//

import CoreLocation
import SwiftUI
import WidgetKit

struct CurrentPostalCodeEntry: TimelineEntry {
    enum Status {
        case place(PostalPlace)
        case needsPermission
        case unavailable
    }

    let date: Date
    let status: Status
}

struct CurrentPostalCodeProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrentPostalCodeEntry {
        CurrentPostalCodeEntry(date: .now, status: .place(.sample))
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrentPostalCodeEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { completion(await entry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrentPostalCodeEntry>) -> Void) {
        Task {
            let entry = await entry()
            let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    private func entry() async -> CurrentPostalCodeEntry {
        let manager = CLLocationManager()
        guard manager.isAuthorizedForWidgetUpdates else {
            return CurrentPostalCodeEntry(date: .now, status: .needsPermission)
        }
        do {
            let location = try await WidgetLocation.current()
            let place = try await GeocoderService().place(for: location)
            return CurrentPostalCodeEntry(date: .now, status: .place(place))
        } catch {
            return CurrentPostalCodeEntry(date: .now, status: .unavailable)
        }
    }
}

/// Una sola lectura de posición con tiempo límite, apta para el proceso del widget.
enum WidgetLocation {
    static func current() async throws -> CLLocation {
        try await withThrowingTaskGroup(of: CLLocation.self) { group in
            group.addTask {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if let location = update.location { return location }
                    if update.authorizationDenied || update.authorizationRestricted {
                        throw PostalError.locationDenied
                    }
                }
                throw PostalError.locationUnavailable
            }
            group.addTask {
                try await Task.sleep(for: .seconds(12))
                throw PostalError.locationUnavailable
            }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }
}

struct CurrentPostalCodeWidget: Widget {
    let kind = "CurrentPostalCodeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrentPostalCodeProvider()) { entry in
            CurrentPostalCodeView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Mi código postal")
        .description("El código postal del lugar donde estás.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct CurrentPostalCodeView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CurrentPostalCodeEntry

    var body: some View {
        switch entry.status {
        case let .place(place):
            placeView(place)
                .widgetURL(AppRouter.searchURL(for: place))
        case .needsPermission:
            message("Abre Codippy y permite la ubicación para ver tu código postal.", icon: "location.slash")
                .widgetURL(AppRouter.locateURL)
        case .unavailable:
            message("Sin ubicación ahora mismo. Toca para buscar.", icon: "location")
                .widgetURL(AppRouter.locateURL)
        }
    }

    @ViewBuilder
    private func placeView(_ place: PostalPlace) -> some View {
        switch family {
        case .accessoryInline:
            Label("\(place.postalCode) · \(place.placeName)", systemImage: "mappin")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "mappin")
                    .font(.caption2)
                Text(place.postalCode)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.6)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(place.postalCode)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text(place.placeName)
                    .font(.caption)
                if let line = place.regionLine {
                    Text(line)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        case .systemMedium:
            HStack(alignment: .center, spacing: 14) {
                CodeChip(code: place.postalCode, large: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(place.placeName)
                        .font(.headline)
                    if let line = place.regionLine {
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(place.countryName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                VStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text(entry.date, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                    Text("Estás en")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer(minLength: 0)
                Text(place.postalCode)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Theme.accent)
                Text(place.placeName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let line = place.regionLine {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func message(_ text: LocalizedStringKey, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension PostalPlace {
    static let sample = PostalPlace(
        countryCode: "ES", postalCode: "28001", placeName: "Madrid", state: "Comunidad de Madrid",
        latitude: 40.4167, longitude: -3.7033, province: "Madrid"
    )
}
