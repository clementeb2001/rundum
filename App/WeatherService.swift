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

struct WeatherCardView: View {
    let card: DashboardCard
    @EnvironmentObject var state: AppState
    @EnvironmentObject var model: WeatherModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var locations = false
    private func temperature(_ value: Measurement<UnitTemperature>) -> String {
        value.converted(to: .celsius).value.formatted(.number.precision(.fractionLength(0))) + "°"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(state.copy("Wetter", "Météo", "Weather"), systemImage: "cloud.sun.fill").font(.headline)
                Spacer()
                Button { locations = true } label: { Label(model.place.name, systemImage: "mappin.and.ellipse").font(.caption).lineLimit(2) }
            }
            if let weather = model.weather {
                HStack {
                    Text(temperature(weather.currentWeather.temperature)).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Spacer()
                    Image(systemName: weather.currentWeather.symbolName).symbolRenderingMode(.multicolor).font(.system(size: 42)).accessibilityLabel(weather.currentWeather.condition.description)
                }
                if let day = weather.dailyForecast.forecast.first {
                    Text(state.copy("Höchstwert ", "Max. ", "High ") + temperature(day.highTemperature) + " · " + state.copy("Tiefstwert ", "Min. ", "Low ") + temperature(day.lowTemperature)).font(.subheadline).foregroundStyle(.secondary)
                }
                if card.size != .small {
                    HStack {
                        Label(temperature(weather.currentWeather.apparentTemperature), systemImage: "thermometer.medium").accessibilityLabel(state.copy("Gefühlt", "Ressenti", "Feels like") + " " + temperature(weather.currentWeather.apparentTemperature))
                        Spacer()
                        Label(weather.currentWeather.wind.speed.converted(to: .kilometersPerHour).value.formatted(.number.precision(.fractionLength(0))) + " km/h", systemImage: "wind")
                    }.font(.subheadline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 22) {
                            ForEach(Array(weather.hourlyForecast.forecast.filter { $0.date > Date() }.prefix(6)), id: \.date) { hour in
                                VStack(spacing: 8) { Text(hour.date, format: .dateTime.hour()); Image(systemName: hour.symbolName).symbolRenderingMode(.multicolor); Text(temperature(hour.temperature)).bold(); Text(hour.precipitationChance, format: .percent.precision(.fractionLength(0))).foregroundStyle(.secondary) }.font(.caption).accessibilityElement(children: .combine)
                            }
                        }.padding(.vertical, 4)
                    }
                }
                if card.size == .large {
                    Divider()
                    ForEach(Array(weather.dailyForecast.forecast.prefix(5)), id: \.date) { day in
                        HStack {
                            Text(day.date, format: .dateTime.weekday(.abbreviated)).frame(width: 50, alignment: .leading)
                            Image(systemName: day.symbolName).symbolRenderingMode(.multicolor)
                            Text(day.precipitationChance, format: .percent.precision(.fractionLength(0))).foregroundStyle(.secondary)
                            Spacer()
                            Text(temperature(day.lowTemperature) + " / " + temperature(day.highTemperature))
                        }.font(.caption).accessibilityElement(children: .combine)
                    }
                }
            } else if model.loading {
                ProgressView(state.copy("Wetter wird geladen …", "Chargement de la météo…", "Loading weather…")).padding(.vertical)
            } else {
                Text(state.copy("Wetter gerade nicht verfügbar.", "Météo indisponible pour le moment.", "Weather is currently unavailable.")).foregroundStyle(.secondary)
            }
            if model.failed {
                Notice(text: state.copy("Die Aktualisierung ist fehlgeschlagen. Bitte Verbindung prüfen und erneut versuchen.", "La mise à jour a échoué. Vérifie la connexion et réessaie.", "The update failed. Check your connection and try again."))
            }
            HStack {
                if let date = model.updated { Text(date, format: .dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button { Task { await model.refresh(force: true) } } label: { Image(systemName: "arrow.clockwise") }.disabled(model.loading).accessibilityLabel(state.copy("Wetter aktualisieren", "Actualiser la météo", "Refresh weather"))
            }
            if let attribution = model.attribution, model.weather != nil {
                HStack {
                    AsyncImage(url: colorScheme == .dark ? attribution.combinedMarkLightURL : attribution.combinedMarkDarkURL) { image in image.resizable().scaledToFit() } placeholder: { Text(attribution.serviceName).font(.caption) }.frame(width: 100, height: 22).accessibilityLabel(attribution.serviceName)
                    Spacer()
                    Link(state.copy("Datenquellen", "Sources des données", "Data sources"), destination: attribution.legalPageURL).font(.caption)
                }
            }
        }.padding(22).background(.background, in: RoundedRectangle(cornerRadius: 26))
            .task(id: model.place.id) { await model.refresh() }
            .sheet(isPresented: $locations) { WeatherLocationView() }
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
