//
//  SearchView.swift
//  codippy
//

import CoreLocation
import SwiftUI

struct SearchView: View {
    @Environment(PostalRepository.self) private var repository
    @AppStorage("selectedCountry") private var selectedCountry = "ES"
    @State private var query = ""
    @State private var results: [PostalPlace] = []
    @State private var errorMessage: String?
    @State private var errorIsHint = false
    @State private var isSearching = false
    @State private var isLocating = false
    @State private var isResolvingNeighborhoods = false
    @State private var showSmartSearch = false
    @State private var showScanner = false
    @State private var showOfflineCountries = false
    @State private var smartTextToAnalyze: String?
    @State private var completerService = SearchCompleterService()
    @State private var path = NavigationPath()
    @State private var router = AppRouter.shared
    @State private var userLocation = UserLocation.shared

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                if isSearching || isLocating {
                    loadingView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            scrollContent
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                        .animation(.snappy, value: results)
                        .animation(.snappy, value: errorMessage)
                    }
                }
            }
            .navigationTitle("Codippy")
            .searchable(text: $query, prompt: "Código postal, ciudad o calle")
            .toolbar {
                ToolbarItem(placement: .automatic) { countryMenu }
                ToolbarItemGroup(placement: .primaryAction) {
                    smartSearchButton
                    scanButton
                    locateButton
                }
            }
            .sheet(isPresented: $showSmartSearch) {
                SmartSearchView(initialText: smartTextToAnalyze) { handleSmartResult($0) }
                    .onDisappear { smartTextToAnalyze = nil }
            }
            .sheet(isPresented: $showScanner) {
                ScanAddressView { handleSmartResult($0) }
            }
            .sheet(isPresented: $showOfflineCountries) {
                OfflineCountriesView()
            }
            .navigationDestination(for: PostalPlace.self) { place in
                PlaceDetailView(place: place)
            }
            .task(id: "\(query)|\(selectedCountry)") {
                await debouncedSearch()
            }
            // Modo demo para capturas de App Store, vía argumentos de lanzamiento
            // (-demoQuery, -demoOpenFirst, -demoSmartText, -demoOfflineSheet, -demoNoSplash). Sin efecto en uso normal.
            .task {
                if let demo = UserDefaults.standard.string(forKey: "demoQuery"), query.isEmpty {
                    query = demo
                }
                if UserDefaults.standard.string(forKey: "demoSmartText") != nil {
                    showSmartSearch = true
                }
                if UserDefaults.standard.bool(forKey: "demoOfflineSheet") {
                    showOfflineCountries = true
                }
            }
            .onChange(of: query, initial: false) {
                updateSuggestions()
            }
            .onChange(of: router.pending, initial: true) {
                consumePendingRoute()
            }
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var scrollContent: some View {
        if !visibleSuggestions.isEmpty {
            suggestionsCard
        }
        if let errorMessage {
            errorCard(errorMessage)
        } else if results.isEmpty {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                emptyState
            }
        } else {
            resultGroups
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Buscando…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .background(.regularMaterial, in: .rect(cornerRadius: 22))
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(Theme.accent, in: Circle())
                .padding(.top, 32)

            VStack(spacing: 6) {
                Text("Encuentra cualquier código postal")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Por código, ciudad o calle · \(countryName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(examples, id: \.self) { example in
                    Button(example) { query = example }
                        .font(.subheadline.weight(.medium))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(.indigo)
                }
            }

            HStack(spacing: 10) {
                Button {
                    showSmartSearch = true
                } label: {
                    Label("Pegar dirección", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                Button {
                    showScanner = true
                } label: {
                    Label("Escanear", systemImage: "text.viewfinder")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.subheadline.weight(.medium))
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(.indigo)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    /// Ejemplos acordes al país: para España los clásicos, para el resto el formato del país.
    private var examples: [String] {
        if selectedCountry == "ES" { return ["28001", "Sevilla", "Gran Vía, Madrid"] }
        if let format = PostalCodeFormat.format(for: selectedCountry) { return [format.example] }
        return []
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: errorIsHint ? "info.circle.fill" : "questionmark.circle.fill")
                .font(.title3)
                .foregroundStyle(errorIsHint ? .indigo : .orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    @ViewBuilder
    private var resultGroups: some View {
        ForEach(groupedResults, id: \.title) { group in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "building.2.fill")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                    Text(group.title)
                        .font(.headline)
                    Spacer()
                    Text("\(group.places.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())
                }
                .padding(.horizontal, 6)

                VStack(spacing: 8) {
                    ForEach(group.places) { place in
                        NavigationLink(value: place) {
                            HStack(spacing: 12) {
                                PlaceRow(place: place, distance: userLocation.distance(to: place))
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .card()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 6)
        }

        if isResolvingNeighborhoods {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Identificando barrios…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("¿Buscabas…?")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 6)
            VStack(spacing: 0) {
                ForEach(visibleSuggestions) { suggestion in
                    Button {
                        query = suggestion.fullText
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.indigo)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(suggestion.title)
                                    .font(.subheadline.weight(.medium))
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 9)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if suggestion.id != visibleSuggestions.last?.id {
                        Divider().padding(.leading, 40)
                    }
                }
            }
            .background(.regularMaterial, in: .rect(cornerRadius: 18))
        }
    }

    // MARK: - Datos derivados

    /// Sugerencias del autocompletado, ocultando la que ya coincide con lo escrito.
    private var visibleSuggestions: [SearchCompleterService.Suggestion] {
        let current = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return completerService.suggestions.filter {
            $0.fullText.caseInsensitiveCompare(current) != .orderedSame
                && $0.title.caseInsensitiveCompare(current) != .orderedSame
        }
    }

    /// Resultados agrupados por barrio; los aún sin resolver van bajo la población.
    /// Las poblaciones que coinciden exactamente con lo buscado van primero.
    private var groupedResults: [(title: String, places: [PostalPlace])] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        func isExact(_ place: PostalPlace) -> Bool {
            place.placeName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) == needle
        }
        let groups = Dictionary(grouping: results) { place in
            place.neighborhood ?? place.placeName
        }
        return groups
            .map { title, places in
                (title: title, places: places.sorted { $0.postalCode < $1.postalCode })
            }
            .sorted { lhs, rhs in
                let lhsExact = lhs.places.contains(where: isExact)
                let rhsExact = rhs.places.contains(where: isExact)
                if lhsExact != rhsExact { return lhsExact }
                return (lhs.places.first?.postalCode ?? "") < (rhs.places.first?.postalCode ?? "")
            }
    }

    private var countryName: String {
        Locale.current.localizedString(forRegionCode: selectedCountry) ?? selectedCountry
    }

    private var countryMenu: some View {
        Menu {
            Picker("País", selection: $selectedCountry) {
                ForEach(repository.countries) { country in
                    Label {
                        if country.isOffline {
                            Text("\(country.name) (offline)")
                        } else {
                            Text(country.name)
                        }
                    } icon: {
                        Image(systemName: country.isOffline ? "arrow.down.circle.fill" : "globe")
                    }
                    .tag(country.code)
                }
            }
            Divider()
            Button {
                showOfflineCountries = true
            } label: {
                Label("Países sin conexión…", systemImage: "square.and.arrow.down")
            }
        } label: {
            CountryBadge(code: selectedCountry)
        }
    }

    private var locateButton: some View {
        Button {
            Task { await locate() }
        } label: {
            Label("¿Dónde estoy?", systemImage: "location")
        }
        .disabled(isLocating)
    }

    private var smartSearchButton: some View {
        Button {
            showSmartSearch = true
        } label: {
            Label("Pegar dirección", systemImage: "sparkles")
        }
    }

    private var scanButton: some View {
        Button {
            showScanner = true
        } label: {
            Label("Escanear dirección", systemImage: "text.viewfinder")
        }
    }

    // MARK: - Acciones

    /// Navegación pedida desde fuera (URL, Atajos, widget, extensión, servicio de macOS).
    private func consumePendingRoute() {
        guard let destination = router.pending else { return }
        router.pending = nil
        path = NavigationPath()
        switch destination {
        case let .search(text, country):
            if let country, repository.supports(country: country) {
                selectedCountry = country
            }
            query = text
        case let .smartText(text):
            smartTextToAnalyze = text
            showSmartSearch = true
        case .locate:
            Task { await locate() }
        }
    }

    /// La consulta que devuelve la IA entra por el flujo de búsqueda normal.
    private func handleSmartResult(_ smart: SmartQuery) {
        if let country = smart.countryCode, repository.supports(country: country) {
            selectedCountry = country
        }
        query = smart.query
    }

    private func updateSuggestions() {
        guard UserDefaults.standard.string(forKey: "demoQuery") == nil else { return }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Para códigos postales puros el autocompletado solo mete ruido.
        if text.allSatisfy({ $0.isNumber || $0 == " " || $0 == "-" }) {
            completerService.update(query: "")
        } else {
            completerService.update(query: text)
        }
    }

    private func debouncedSearch() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(400))
        } catch {
            return
        }

        isSearching = true
        do {
            let found = try await repository.search(text, country: selectedCountry)
            results = found
            errorMessage = nil
            isSearching = false
            if UserDefaults.standard.bool(forKey: "demoOpenFirst"), let first = found.first {
                path.append(first)
            }
            await resolveNeighborhoods()
        } catch is CancellationError {
            // Nueva búsqueda en curso.
        } catch {
            isSearching = false
            guard !Task.isCancelled else { return }
            results = []
            errorIsHint = (error as? PostalError)?.isHint ?? false
            errorMessage = error.localizedDescription
        }
    }

    /// Rellena progresivamente el barrio de cada resultado (secuencial para no
    /// saturar el geocoder de Apple; con caché en el repositorio).
    private func resolveNeighborhoods() async {
        isResolvingNeighborhoods = true
        defer { isResolvingNeighborhoods = false }
        for index in results.indices.prefix(40) {
            guard !Task.isCancelled else { return }
            guard results.indices.contains(index), results[index].neighborhood == nil else { continue }
            let place = results[index]
            guard let neighborhood = await repository.neighborhood(for: place) else { continue }
            if results.indices.contains(index), results[index].id == place.id {
                results[index].neighborhood = neighborhood
            }
        }
    }

    private func locate() async {
        isLocating = true
        defer { isLocating = false }
        do {
            let place = try await LocationService().currentPlace()
            query = ""
            results = [place]
            errorMessage = nil
            if !place.countryCode.isEmpty {
                selectedCountry = place.countryCode.uppercased()
            }
        } catch {
            results = []
            errorIsHint = false
            errorMessage = error.localizedDescription
        }
    }
}

struct PlaceRow: View {
    let place: PostalPlace
    var distance: CLLocationDistance? = nil

    var body: some View {
        HStack(spacing: 12) {
            CodeChip(code: place.postalCode)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.street ?? place.placeName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                if let subtitle = place.street != nil ? place.placeName : place.regionLine {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let distance {
                Text(UserLocation.formatted(distance))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            CountryBadge(code: place.countryCode)
        }
    }
}

#Preview {
    SearchView()
        .environment(PostalRepository())
}
