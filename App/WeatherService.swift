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
    @Published private(set) var locating = false
    @Published private(set) var locationDenied = false
    private let service = WeatherService.shared
    private let manager = CLLocationManager()
    private var requestID = UUID()
    private var locationWanted = false
    private var locationTimeout: Task<Void, Never>?
    func setHistoryAttribution(_ value: WeatherAttribution) { attribution = value }
    override init() {
        place = UserDefaults.standard.data(forKey: "weatherPlace").flatMap { try? JSONDecoder().decode(WeatherPlace.self, from: $0) } ?? .luxembourg
        super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }
    func select(_ place: WeatherPlace) {
        requestID = UUID(); loading = false; weather = nil; attribution = nil; updated = nil; failed = false
        locationWanted = false; locating = false; locationTimeout?.cancel()
        self.place = place
        if let data = try? JSONEncoder().encode(place) { UserDefaults.standard.set(data, forKey: "weatherPlace") }
    }
    func refresh(force: Bool = false) async {
        guard !loading, force || (updated.map({ Date().timeIntervalSince($0) > 900 }) ?? true) else { return }
        let id = UUID(); requestID = id; loading = true; failed = false
        defer { if requestID == id { loading = false } }
        do {
            async let forecast = service.weather(for: place.location)
            async let credits = service.attribution
            let result = try await (forecast, credits)
            guard requestID == id, !Task.isCancelled else { return }
            weather = result.0; attribution = result.1; updated = Date()
        } catch {
            guard requestID == id else { return }
            failed = true
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
