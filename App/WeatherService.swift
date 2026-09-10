import SwiftUI
import WeatherKit
import CoreLocation

struct WeatherPlace: Codable, Equatable, Identifiable {
    var name: String
    var latitude: Double
    var longitude: Double
    var id: String { "\(latitude),\(longitude)" }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
    static let luxembourg = Self(name: "Luxembourg", latitude: 49.6116, longitude: 6.1319)
    static let nearby: [Self] = [.luxembourg, .init(name: "Esch-sur-Alzette", latitude: 49.4958, longitude: 5.9806), .init(name: "Diekirch", latitude: 49.8678, longitude: 6.1558), .init(name: "Trier", latitude: 49.7499, longitude: 6.6371), .init(name: "Metz", latitude: 49.1193, longitude: 6.1757), .init(name: "Arlon", latitude: 49.6833, longitude: 5.8167)]
}

@MainActor final class WeatherModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var place: WeatherPlace
    @Published private(set) var weather: Weather?
    @Published private(set) var attribution: WeatherAttribution?
    @Published private(set) var loading = false
    @Published private(set) var updated: Date?
    @Published private(set) var failed = false
    @Published private(set) var diagnostic: String?
    @Published private(set) var locating = false
    @Published private(set) var locationDenied = false
    private let service = WeatherService.shared
    private let manager = CLLocationManager()
    private var requestID = UUID()
    private var fetchTask: Task<Void, Never>?
    private var fetchTimeout: Task<Void, Never>?
    private var locationWanted = false
    private var locationTimeout: Task<Void, Never>?
    private let offlineTest = ProcessInfo.processInfo.arguments.contains("--weather-offline-test")
    func setHistoryAttribution(_ value: WeatherAttribution) { attribution = value }
    override init() {
        place = UserDefaults.standard.data(forKey: "weatherPlace").flatMap { try? JSONDecoder().decode(WeatherPlace.self, from: $0) } ?? .luxembourg
        super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        if ProcessInfo.processInfo.arguments.contains("--weather-offline-test") { failed = true; diagnostic = "offline test"; return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--weather-diagnostic") {
            Task { await refresh(force: true) }
        }
        #endif
    }
    func select(_ place: WeatherPlace) {
        fetchTask?.cancel(); fetchTimeout?.cancel(); fetchTask = nil
        requestID = UUID(); loading = false; weather = nil; attribution = nil; updated = nil; failed = false; diagnostic = nil
        locationWanted = false; locating = false; locationTimeout?.cancel()
        self.place = place
        if let data = try? JSONEncoder().encode(place) { UserDefaults.standard.set(data, forKey: "weatherPlace") }
    }
    func refresh(force: Bool = false) async {
        if offlineTest { loading = false; failed = true; diagnostic = "offline test"; return }
        // The shared request belongs to the model, not a dashboard view's lifetime.
        // Opening details must not abandon a request cancelled by SwiftUI navigation.
        if loading && !force { await fetchTask?.value; return }
        guard force || (updated.map({ Date().timeIntervalSince($0) > 900 }) ?? true) else { return }
        fetchTask?.cancel(); fetchTimeout?.cancel()
        let id = UUID(); requestID = id; loading = true; failed = false; diagnostic = nil
        let location = place.location
        fetchTask = Task { [weak self] in await self?.fetch(location: location, id: id) }
        fetchTimeout = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
            guard let self, requestID == id, loading else { return }
            fetchTask?.cancel(); requestID = UUID(); loading = false; failed = true
            diagnostic = "WeatherKit · timeout (30 s)"
            #if DEBUG
            print("RundumWeather: timeout"); fflush(stdout)
            #endif
        }
        await fetchTask?.value
    }
    private func fetch(location: CLLocation, id: UUID) async {
        defer { if requestID == id { loading = false } }
        var stage = "forecast"
        do {
            let forecast = try await service.weather(for: location)
            stage = "attribution"
            let credits = try await service.attribution
            guard requestID == id, !Task.isCancelled else { return }
            weather = forecast; attribution = credits; updated = Date(); fetchTimeout?.cancel()
            #if DEBUG
            print("RundumWeather: success forecast + attribution"); fflush(stdout)
            #endif
        } catch {
            guard requestID == id, !Task.isCancelled else { return }
            failed = true; fetchTimeout?.cancel()
            let ns = error as NSError
            // Never expose coordinates, URLs, tokens or arbitrary error userInfo.
            diagnostic = "\(stage) · \(ns.domain) (\(ns.code))"
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
                diagnostic = (diagnostic ?? "") + " · \(underlying.domain) (\(underlying.code))"
            }
            #if DEBUG
            print("RundumWeather: " + (diagnostic ?? "failed")); fflush(stdout)
            #endif
        }
    }
    func useCurrentLocation() {
        locationDenied = false; locationWanted = true; locating = true
        locationTimeout?.cancel()
        locationTimeout = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
            guard let self, locationWanted else { return }; locationWanted = false; locating = false; locationDenied = true
        }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: locationDenied = true; locationWanted = false; locating = false; locationTimeout?.cancel()
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.locationWanted else { return }
            switch self.manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse: self.manager.requestLocation()
            case .denied, .restricted: self.locationDenied = true; self.locationWanted = false; self.locating = false; self.locationTimeout?.cancel()
            default: break
            }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            guard self.locationWanted else { return }
            // City-scale coordinates only. Never persist the exact device position.
            let lat = (coordinate.latitude * 100).rounded() / 100, lon = (coordinate.longitude * 100).rounded() / 100
            self.select(.init(name: "\(lat), \(lon)", latitude: lat, longitude: lon))
            await self.refresh(force: true)
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.locationDenied = true; self.locationWanted = false; self.locating = false; self.locationTimeout?.cancel() }
    }
}


struct WeatherLocationView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var model: WeatherModel
    @Environment(\.dismiss) var dismiss
    @State private var query = ""
    @State private var results: [WeatherPlace] = []
    @State private var searching = false
    @State private var failed = false
    @State private var geocoder = CLGeocoder()
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(state.copy("Für Wetter sendet Rundum die Koordinaten des gewählten Orts an Apple. Dein aktueller Standort wird nur auf Wunsch einmalig und gerundet verwendet. Es gibt keine Hintergrund-Ortung.", "Pour la météo, Rundum envoie à Apple les coordonnées du lieu choisi. Ta position n’est utilisée qu’à ta demande, une seule fois et arrondie. Aucun suivi en arrière-plan.", "For weather, Rundum sends your chosen place’s coordinates to Apple. Your current location is used only on request, once and rounded. There is no background tracking.")).font(.footnote)
                    Button { model.useCurrentLocation() } label: { Label(state.copy("Aktuellen Standort verwenden", "Utiliser ma position", "Use current location"), systemImage: "location") }.disabled(model.locating)
                    if model.locating { ProgressView() }
                    if model.locationDenied { Text(state.copy("Standort nicht verfügbar. Wähle einen Ort oder prüfe die iOS-Freigabe.", "Position indisponible. Choisis un lieu ou vérifie l’autorisation iOS.", "Location unavailable. Choose a place or check iOS permissions.")).font(.footnote) }
                }
                Section(state.copy("Ort suchen", "Rechercher un lieu", "Find a place")) {
                    TextField(state.copy("Stadt", "Ville", "City"), text: $query).submitLabel(.search).onSubmit { search() }
                    Button(state.copy("Suchen", "Rechercher", "Search")) { search() }.disabled(searching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text(state.copy("Die Suchanfrage wird an Apples Ortsdienst gesendet.", "La recherche est envoyée au service de lieux d’Apple.", "The search query is sent to Apple’s geocoding service.")).font(.caption).foregroundStyle(.secondary)
                    if searching { ProgressView() }
                    if failed { Text(state.copy("Kein Ort gefunden oder keine Verbindung.", "Lieu introuvable ou connexion indisponible.", "Place not found or connection unavailable.")).font(.footnote) }
                    ForEach(results) { place in placeButton(place) }
                }
                Section(state.copy("Großregion", "Grande Région", "Nearby cities")) { ForEach(WeatherPlace.nearby) { place in placeButton(place) } }
            }.navigationTitle(state.copy("Wetterort", "Lieu météo", "Weather location"))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(state.copy("Fertig", "Terminé", "Done")) { dismiss() } } }
                .onDisappear { geocoder.cancelGeocode() }
        }
    }
    private func placeButton(_ place: WeatherPlace) -> some View {
        Button { model.select(place); dismiss() } label: { HStack { Text(place.name); Spacer(); if model.place == place { Image(systemName: "checkmark") } } }
    }
    private func search() {
        guard !searching, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        searching = true; failed = false
        Task {
            defer { searching = false }
            do {
                let places = try await geocoder.geocodeAddressString(query)
                var seen = Set<String>()
                results = places.compactMap { place in
                    guard let point = place.location?.coordinate else { return nil }
                    let value = WeatherPlace(name: [place.locality ?? place.name, place.country].compactMap { $0 }.joined(separator: ", "), latitude: point.latitude, longitude: point.longitude)
                    return seen.insert(value.id).inserted ? value : nil
                }; failed = results.isEmpty
            } catch { failed = true; results = [] }
        }
    }
}
