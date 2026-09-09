import SwiftUI
import WeatherKit
import Charts

func weatherTemperature(_ value: Measurement<UnitTemperature>) -> String {
    value.converted(to: .celsius).value.formatted(.number.precision(.fractionLength(0))) + "°"
}
struct WeatherCredits: View {
    @EnvironmentObject var model: WeatherModel
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        if let attribution = model.attribution {
            HStack {
                AsyncImage(url: scheme == .dark ? attribution.combinedMarkLightURL : attribution.combinedMarkDarkURL) { image in image.resizable().scaledToFit() } placeholder: { Text(attribution.serviceName).font(.caption) }.frame(width: 96, height: 22).accessibilityLabel(attribution.serviceName)
                Spacer()
                Link(state.copy("Datenquellen", "Sources", "Data sources"), destination: attribution.legalPageURL).font(.caption)
            }
        }
    }
}
struct RichWeatherCardView: View {
    let card: DashboardCard
    @EnvironmentObject var model: WeatherModel
    @EnvironmentObject var state: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardHeading(card: card, subtitle: model.place.name)
            if let weather = model.weather {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(weatherTemperature(weather.currentWeather.temperature)).font(.system(size: card.size == .small ? 48 : 64, weight: .light, design: .rounded)).monospacedDigit()
                        Text(weather.currentWeather.condition.description).font(.subheadline.weight(.medium))
                        if let day = weather.dailyForecast.forecast.first {
                            Text("↑ " + weatherTemperature(day.highTemperature) + "   ↓ " + weatherTemperature(day.lowTemperature)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: weather.currentWeather.symbolName).symbolRenderingMode(.multicolor).font(.system(size: 58)).padding(12).background(card.accent.opacity(0.08), in: Circle()).accessibilityHidden(true)
                }
                if card.size != .small {
                    Divider()
                    if card.presentation == .line {
                        MetricChart(points: hours(weather), card: card, compact: true, selected: .constant(nil))
                        Text(state.copy("Temperatur · nächste 12 Stunden", "Température · 12 prochaines heures", "Temperature · next 12 hours")).font(.caption2).foregroundStyle(.secondary)
                    } else if card.presentation == .bars {
                        ForEach(Array(weather.dailyForecast.forecast.prefix(3)), id: \.date) { day in TemperatureDayRow(day: day, forecast: weather.dailyForecast.forecast, color: card.accent) }
                    } else {
                        WeatherHours(hours: Array(weather.hourlyForecast.forecast.filter { $0.date >= Date().addingTimeInterval(-3600) }.prefix(6)), color: card.accent)
                    }
                }
                if card.size == .large {
                    HStack {
                        Label(weatherTemperature(weather.currentWeather.apparentTemperature), systemImage: "thermometer.medium")
                        Spacer()
                        Label(weather.currentWeather.wind.speed.converted(to: .kilometersPerHour).value.formatted(.number.precision(.fractionLength(0))) + " km/h", systemImage: "wind")
                    }.font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Label(state.copy("Wetter", "Météo", "Weather"), systemImage: "cloud.sun.fill").font(.largeTitle).foregroundStyle(card.accent)
                Text(model.loading ? state.copy("Wetter wird geladen …", "Chargement de la météo…", "Loading weather…") : state.copy("Wetter gerade nicht verfügbar. Tippe für Details.", "Météo indisponible. Touche pour les détails.", "Weather unavailable. Tap for details.")).font(.subheadline).foregroundStyle(.secondary)
            }
            if model.failed { Label(state.copy("Aktualisierung fehlgeschlagen", "Échec de la mise à jour", "Update failed"), systemImage: "exclamationmark.arrow.triangle.2.circlepath").font(.caption).foregroundStyle(.secondary) }
            if let updated = model.updated { Text(updated, format: .dateTime.day().month().hour().minute()).font(.caption2).foregroundStyle(.secondary) }
        }.modifier(CardPanel(card: card)).task(id: model.place.id) { await model.refresh() }
    }
    private func hours(_ weather: Weather) -> [MetricPoint] {
        weather.hourlyForecast.forecast.filter { $0.date >= Date().addingTimeInterval(-3600) }.prefix(12).map { .init(date: $0.date, end: $0.date.addingTimeInterval(3600), value: $0.temperature.converted(to: .celsius).value) }
    }
}
struct WeatherHours: View {
    let hours: [HourWeather]
    let color: Color
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                ForEach(hours, id: \.date) { hour in
                    VStack(spacing: 9) {
                        Text(hour.date, format: .dateTime.hour()).font(.caption).foregroundStyle(.secondary)
                        Image(systemName: hour.symbolName).symbolRenderingMode(.multicolor).font(.title3).accessibilityLabel(hour.condition.description)
                        Text(weatherTemperature(hour.temperature)).font(.subheadline.bold())
                        Text(hour.precipitationChance, format: .percent.precision(.fractionLength(0))).font(.caption2).foregroundStyle(color)
                    }.frame(minWidth: 34).accessibilityElement(children: .combine)
                }
            }.padding(.vertical, 4)
        }
    }
}
struct TemperatureDayRow: View {
    let day: DayWeather
    let forecast: [DayWeather]
    let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Text(day.date, format: .dateTime.weekday(.abbreviated)).font(.subheadline).frame(width: 44, alignment: .leading)
            Image(systemName: day.symbolName).symbolRenderingMode(.multicolor).frame(width: 24).accessibilityLabel(day.condition.description)
            Text(weatherTemperature(day.lowTemperature)).font(.subheadline).monospacedDigit().foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
            GeometryReader { geometry in
                let low = forecast.map { $0.lowTemperature.converted(to: .celsius).value }.min() ?? 0
                let high = forecast.map { $0.highTemperature.converted(to: .celsius).value }.max() ?? 1
                let span = max(high - low, 1)
                let start = (day.lowTemperature.converted(to: .celsius).value - low) / span
                let width = (day.highTemperature.converted(to: .celsius).value - day.lowTemperature.converted(to: .celsius).value) / span
                Capsule().fill(color.opacity(0.08))
                Capsule().fill(LinearGradient(colors: [.cyan, color, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(5, geometry.size.width * width)).offset(x: geometry.size.width * start)
            }.frame(height: 6).accessibilityHidden(true)
            Text(weatherTemperature(day.highTemperature)).font(.subheadline.weight(.semibold)).monospacedDigit().frame(width: 36, alignment: .trailing)
        }.padding(.vertical, 5).accessibilityElement(children: .combine)
    }
}
struct WeatherHistoryDay: Identifiable {
    let date: Date
    let low: Double
    let high: Double
    var id: Date { date }
}
struct WeatherDetailView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var model: WeatherModel
    @Environment(\.scenePhase) private var phase
    @State private var historical = false
    @State private var period: HistoryPeriod = .month
    @State private var date = Date()
    @State private var days: [WeatherHistoryDay] = []
    @State private var loading = false
    @State private var failed = false
    @State private var location = false
    @State private var customize = false
    @State private var requestID = UUID()
    private var card: DashboardCard { state.configuration.cards.first { $0.id == .weather } ?? .init(id: .weather) }
    private var taskID: String { "\(historical)-\(period.rawValue)-\(date.timeIntervalSince1970)-\(model.place.id)" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Label(model.place.name, systemImage: "mappin.and.ellipse").font(.headline)
                    Spacer()
                    Button(state.copy("Ort ändern", "Changer de lieu", "Change place")) { location = true }.font(.subheadline)
                }
                Picker(state.copy("Ansicht", "Vue", "View"), selection: $historical) {
                    Text(state.copy("Vorhersage", "Prévisions", "Forecast")).tag(false)
                    Text(state.copy("Verlauf", "Historique", "History")).tag(true)
                }.pickerStyle(.segmented)
                if historical { historyView } else { forecastView }
                WeatherCredits()
            }.padding(22).frame(maxWidth: 760)
        }.background(Palette.paper).navigationTitle(state.copy("Wetter", "Météo", "Weather")).navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { customize = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel(state.copy("Karte gestalten", "Personnaliser la carte", "Customize card")) } }
            .sheet(isPresented: $location) { WeatherLocationView() }
            .sheet(isPresented: $customize) { CardCustomizationView(kind: .weather) }
            .task(id: taskID) { if historical { await loadHistory() } else { await model.refresh() } }
            .onChange(of: phase) { phase in if phase == .active { Task { if historical { await loadHistory() } else { await model.refresh() } } } }
            .refreshable { if historical { await loadHistory() } else { await model.refresh(force: true) } }
    }
    @ViewBuilder private var forecastView: some View {
        RichWeatherCardView(card: DashboardCard(id: .weather, size: .large, tint: card.tint, surface: card.surface, presentation: .value))
        if let weather = model.weather {
            VStack(alignment: .leading, spacing: 18) {
                Label(state.copy("Nächste 24 Stunden", "24 prochaines heures", "Next 24 hours"), systemImage: "clock").font(.headline)
                WeatherHours(hours: Array(weather.hourlyForecast.forecast.filter { $0.date >= Date().addingTimeInterval(-3600) }.prefix(24)), color: card.accent)
            }.modifier(CardPanel(card: card))
            VStack(alignment: .leading, spacing: 12) {
                Label(state.copy("Tagesvorhersage", "Prévisions quotidiennes", "Daily forecast"), systemImage: "calendar").font(.headline)
                ForEach(weather.dailyForecast.forecast, id: \.date) { day in
                    TemperatureDayRow(day: day, forecast: weather.dailyForecast.forecast, color: card.accent)
                    HStack { Spacer(); Text(state.copy("Regenwahrscheinlichkeit ", "Probabilité de pluie ", "Rain chance ") + day.precipitationChance.formatted(.percent.precision(.fractionLength(0)))).font(.caption).foregroundStyle(.secondary) }
                    Divider()
                }
            }.modifier(CardPanel(card: card))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 14) {
                weatherFact(state.copy("Gefühlt", "Ressenti", "Feels like"), weatherTemperature(weather.currentWeather.apparentTemperature), "thermometer.medium")
                weatherFact(state.copy("Wind", "Vent", "Wind"), weather.currentWeather.wind.speed.converted(to: .kilometersPerHour).value.formatted(.number.precision(.fractionLength(0))) + " km/h", "wind")
                weatherFact(state.copy("Luftfeuchte", "Humidité", "Humidity"), weather.currentWeather.humidity.formatted(.percent.precision(.fractionLength(0))), "humidity")
                weatherFact("UV", String(weather.currentWeather.uvIndex.value), "sun.max")
                if let sunrise = weather.dailyForecast.forecast.first?.sun.sunrise { weatherFact(state.copy("Sonnenaufgang", "Lever du soleil", "Sunrise"), sunrise.formatted(date: .omitted, time: .shortened), "sunrise") }
                if let sunset = weather.dailyForecast.forecast.first?.sun.sunset { weatherFact(state.copy("Sonnenuntergang", "Coucher du soleil", "Sunset"), sunset.formatted(date: .omitted, time: .shortened), "sunset") }
            }
        }
        if model.failed || model.weather == nil {
            Button(state.copy("Wetter erneut laden", "Recharger la météo", "Reload weather")) { Task { await model.refresh(force: true) } }.buttonStyle(.bordered).disabled(model.loading)
        }
    }
    private func weatherFact(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.title2, design: .rounded, weight: .semibold))
        }.frame(maxWidth: .infinity, alignment: .leading).modifier(CardPanel(card: card))
    }
    @ViewBuilder private var historyView: some View {
        PeriodControl(period: $period, date: $date)
        if #available(iOS 18.0, *) {
            if loading { ProgressView(state.copy("Wetterverlauf wird geladen …", "Chargement de l’historique…", "Loading weather history…")).frame(maxWidth: .infinity).padding(40) }
            else if failed {
                VStack(alignment: .leading, spacing: 14) {
                    Text(state.copy("Apple hat für diesen Ort und Zeitraum keine abrufbaren Verlaufsdaten geliefert. Prüfe Verbindung und WeatherKit-Freigabe.", "Aucune donnée historique accessible pour ce lieu et cette période. Vérifie la connexion et WeatherKit.", "Apple did not return accessible history for this place and period. Check connection and WeatherKit access."))
                    Button(state.copy("Erneut versuchen", "Réessayer", "Try again")) { Task { await loadHistory() } }
                }.modifier(CardPanel(card: card))
            } else if days.isEmpty {
                Text(state.copy("Noch keine abgeschlossenen Tage in diesem Zeitraum. Wähle einen früheren Zeitraum.", "Aucun jour terminé pour cette période. Choisis une période antérieure.", "No completed days in this period yet. Choose an earlier period.")).foregroundStyle(.secondary).padding(.vertical, 24)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    Label(state.copy("Gemessene Tageshöchst- und Tiefstwerte", "Maximums et minimums observés", "Observed daily highs and lows"), systemImage: "thermometer.medium").font(.headline)
                    Chart(days) { day in
                        BarMark(x: .value("Date", day.date, unit: .day), yStart: .value("Low °C", day.low), yEnd: .value("High °C", day.high)).foregroundStyle(card.accent.gradient).cornerRadius(3)
                    }.frame(height: 230).chartYScale(domain: ((days.map(\.low).min() ?? 0) - 2)...((days.map(\.high).max() ?? 1) + 2))
                    Text(state.copy("°C · tatsächliche Tageswerte, keine Klimamittelwerte und keine Vorhersage.", "°C · valeurs observées, ni moyennes climatiques ni prévisions.", "°C · observed daily values, not climate averages or forecasts.")).font(.caption).foregroundStyle(.secondary)
                }.modifier(CardPanel(card: card))
                LazyVStack(spacing: 0) {
                    ForEach(Array(days.reversed())) { day in
                        HStack {
                            Text(day.date, format: .dateTime.day().month(.abbreviated).year())
                            Spacer()
                            Text(day.low.formatted(.number.precision(.fractionLength(0))) + "° / " + day.high.formatted(.number.precision(.fractionLength(0))) + "°").monospacedDigit().foregroundStyle(card.accent)
                        }.font(.subheadline).padding(.vertical, 12).accessibilityElement(children: .combine)
                        Divider()
                    }
                }.modifier(CardPanel(card: card))
            }
            Text(state.copy("Historische Daten werden für den gewählten Ort bei Apple abgefragt, frühestens ab August 2021. Verfügbarkeit kann variieren; fehlende Tage werden nicht ergänzt. Datumsanzeigen verwenden die Zeitzone deines iPhones.", "Les données historiques du lieu choisi sont demandées à Apple, au plus tôt à partir d’août 2021. La disponibilité varie ; les jours absents ne sont pas inventés. Les dates utilisent le fuseau horaire de ton iPhone.", "History for the selected place is requested from Apple, no earlier than August 2021. Availability varies; missing days are not filled in. Dates use your iPhone’s time zone.")).font(.caption).foregroundStyle(.secondary)
        } else {
            Text(state.copy("Wetter-Verläufe benötigen iOS 18 oder neuer. Die aktuelle Vorhersage kannst du weiterhin nutzen.", "L’historique météo nécessite iOS 18 ou ultérieur. Les prévisions restent disponibles.", "Weather history requires iOS 18 or later. Current forecasts remain available.")).foregroundStyle(.secondary)
        }
    }
    @MainActor private func loadHistory() async {
        guard #available(iOS 18.0, *) else { return }
        let id = UUID(); requestID = id; loading = true; failed = false; days = []
        defer { if requestID == id { loading = false } }
        let interval = period.interval(containing: date)
        let oldest = Date(timeIntervalSince1970: 1627776000)
        let start = max(interval.start, oldest), end = min(interval.end, Calendar.current.startOfDay(for: Date()))
        guard end > start else { return }
        let place = model.place
        do {
            // Daily summaries are observations, unlike WeatherKit's long-term statistics API.
            let summary = try await WeatherService.shared.dailySummary(for: place.location, forDaysIn: DateInterval(start: start, end: end), including: .temperature)
            let attribution = try await WeatherService.shared.attribution
            guard !Task.isCancelled, requestID == id, model.place == place else { return }
            model.setHistoryAttribution(attribution)
            days = summary.days.filter { $0.date >= start && $0.date < end }.map { .init(date: $0.date, low: $0.lowTemperature.converted(to: .celsius).value, high: $0.highTemperature.converted(to: .celsius).value) }.sorted { $0.date < $1.date }
        } catch { if !Task.isCancelled, requestID == id { failed = true } }
    }
}
