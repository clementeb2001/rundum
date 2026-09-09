import SwiftUI
import Charts

extension Copy {
    func title(_ period: HistoryPeriod) -> String {
        switch period { case .day: return self("Tag", "Jour", "Day"); case .week: return self("Woche", "Semaine", "Week"); case .month: return self("Monat", "Mois", "Month"); case .year: return self("Jahr", "Année", "Year") }
    }
    func title(_ style: CardPresentation) -> String {
        switch style { case .value: return self("Kennzahl", "Valeur", "Value"); case .bars: return self("Balken", "Barres", "Bars"); case .line: return self("Linie", "Courbe", "Line"); case .ring: return self("Zielring", "Anneau", "Goal ring"); case .agenda: return self("Agenda", "Agenda", "Agenda") }
    }
    func title(_ surface: CardSurface) -> String {
        switch surface { case .plain: return self("Klar", "Simple", "Clean"); case .tinted: return self("Getönt", "Teinté", "Tinted"); case .gradient: return self("Verlauf", "Dégradé", "Gradient") }
    }
    func title(_ tint: CardTint) -> String {
        switch tint {
        case .automatic: return self("Automatisch", "Automatique", "Automatic")
        case .coral: return self("Koralle", "Corail", "Coral")
        case .orange: return "Orange"
        case .gold: return self("Gold", "Or", "Gold")
        case .green: return self("Grün", "Vert", "Green")
        case .teal: return self("Petrol", "Sarcelle", "Teal")
        case .blue: return self("Blau", "Bleu", "Blue")
        case .indigo: return "Indigo"
        case .pink: return self("Pink", "Rose", "Pink")
        }
    }
    func unit(_ kind: CardKind) -> String {
        switch kind { case .steps: return self("Schritte", "pas", "steps"); case .sleep: return self("Std.", "h", "hr"); case .heart: return "bpm"; case .workouts: return "min"; case .weather: return "°C"; default: return self("Termine", "événements", "events") }
    }
}
extension DashboardCard {
    var accent: Color {
        let resolved: CardTint
        if tint == .automatic {
            switch id { case .steps: resolved = .orange; case .sleep: resolved = .indigo; case .heart: resolved = .coral; case .workouts: resolved = .green; case .weather: resolved = .blue; default: resolved = .teal }
        } else { resolved = tint }
        switch resolved {
        case .coral: return adaptive((0.82, 0.16, 0.25), (1, 0.43, 0.50))
        case .orange: return adaptive((0.74, 0.32, 0.04), (1, 0.63, 0.25))
        case .gold: return adaptive((0.56, 0.40, 0.04), (0.95, 0.80, 0.30))
        case .green: return adaptive((0.12, 0.48, 0.23), (0.40, 0.84, 0.54))
        case .blue: return .blue
        case .indigo: return .indigo
        case .pink: return .pink
        default: return adaptive((0.12, 0.40, 0.36), (0.34, 0.82, 0.73))
        }
    }
    private func adaptive(_ light: (Double, Double, Double), _ dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}
struct CardPanel: ViewModifier {
    let card: DashboardCard
    func body(content: Content) -> some View {
        content.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Color(uiColor: .secondarySystemGroupedBackground)
                if card.surface != .plain {
                    LinearGradient(colors: [card.accent.opacity(card.surface == .gradient ? 0.18 : 0.10), card.accent.opacity(card.surface == .gradient ? 0.025 : 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(card.accent.opacity(0.10), lineWidth: 1))
    }
}
struct CardHeading: View {
    let card: DashboardCard
    let subtitle: String
    @EnvironmentObject var state: AppState
    var body: some View {
        HStack(alignment: .center) {
            Label(state.copy.card(card.id), systemImage: card.id.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(card.accent)
            Spacer(minLength: 8)
            Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.trailing)
            Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(.tertiary).accessibilityHidden(true)
        }
    }
}
func metricText(_ value: Double?, kind: CardKind) -> String {
    guard let value else { return "—" }
    return value.formatted(.number.precision(.fractionLength(kind == .sleep ? 1 : 0)))
}
struct MetricHeadline: View {
    let value: Double?
    let card: DashboardCard
    @EnvironmentObject var state: AppState
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) { number; unit }
            VStack(alignment: .leading, spacing: 2) { number; unit }
        }.accessibilityElement(children: .combine)
    }
    private var number: some View { Text(metricText(value, kind: card.id)).font(.system(size: card.size == .small ? 34 : 42, weight: .bold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.65).lineLimit(1) }
    private var unit: some View { Text(state.copy.unit(card.id)).font(.subheadline.weight(.medium)).foregroundStyle(.secondary) }
}
struct GoalRing: View {
    let value: Double?
    let goal: Double?
    let color: Color
    @EnvironmentObject var state: AppState
    var body: some View {
        let progress = HistoryMath.progress(value: value, goal: goal)
        ZStack {
            Circle().stroke(color.opacity(0.13), lineWidth: 12)
            if let progress { Circle().trim(from: 0, to: progress).stroke(AngularGradient(colors: [color.opacity(0.5), color], center: .center, startAngle: .degrees(0), endAngle: .degrees(360)), style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90)) }
            VStack(spacing: 2) {
                Text(progress.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—").font(.system(.title3, design: .rounded, weight: .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                Text(state.copy("Ziel", "Objectif", "Goal")).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
            }
        }.padding(7).frame(width: 106, height: 106).accessibilityElement(children: .ignore)
            .accessibilityLabel(state.copy("Zielerreichung", "Progression", "Goal progress"))
            .accessibilityValue(progress.map { $0.formatted(.percent) } ?? state.copy.missing)
    }
}

/// Missing buckets split line series instead of drawing a continuous line across missing data.
struct MetricChart: View {
    let points: [MetricPoint]
    let card: DashboardCard
    var compact = false
    @Binding var selected: Date?
    @EnvironmentObject var state: AppState
    private var segmented: [(point: MetricPoint, segment: Int)] {
        var segment = 0
        return points.map { point in if point.value == nil { segment += 1 }; return (point, segment) }
    }
    private var domain: ClosedRange<Date> {
        let start = points.first?.date ?? Date()
        return start...max(points.last?.end ?? start.addingTimeInterval(3600), start.addingTimeInterval(1))
    }
    var body: some View {
        if points.contains(where: { $0.value != nil }) {
            Chart {
                ForEach(segmented, id: \.point.id) { item in
                    if let value = item.point.value {
                        if card.presentation == .line {
                            LineMark(x: .value("Date", item.point.date), y: .value(state.copy.unit(card.id), value), series: .value("Segment", item.segment)).foregroundStyle(card.accent).lineStyle(StrokeStyle(lineWidth: compact ? 2.5 : 3))
                            PointMark(x: .value("Date", item.point.date), y: .value(state.copy.unit(card.id), value)).foregroundStyle(card.accent).symbolSize(compact ? 12 : 25)
                        } else {
                            BarMark(xStart: .value("Start", item.point.date.addingTimeInterval(item.point.end.timeIntervalSince(item.point.date) * 0.12)), xEnd: .value("End", item.point.end.addingTimeInterval(-item.point.end.timeIntervalSince(item.point.date) * 0.12)), y: .value(state.copy.unit(card.id), value)).foregroundStyle(card.accent.gradient).cornerRadius(4)
                        }
                    }
                }
                if let selected, !compact {
                    RuleMark(x: .value("Selection", selected)).foregroundStyle(.secondary).lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
            }
            .chartXScale(domain: domain)
            .chartXAxis(compact ? .hidden : .automatic)
            .chartYAxis(compact ? .hidden : .automatic)
            .chartOverlay { proxy in
                if !compact {
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                            guard let date: Date = proxy.value(atX: x) else { return }
                            selected = points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })?.date
                        })
                    }
                }
            }
            .frame(height: compact ? 64 : 220)
            .accessibilityLabel(state.copy("Verlauf", "Historique", "History") + " · " + state.copy.card(card.id))
        } else {
            HStack(spacing: 10) { Image(systemName: "chart.bar.xaxis").font(.title2); Text(state.copy("Noch keine Werte im Zeitraum", "Aucune valeur pour cette période", "No values in this period yet")).font(.subheadline) }
                .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: compact ? 64 : 140)
        }
    }
}

struct RichMetricCardView: View {
    let card: DashboardCard
    let events: [CalendarItem]
    @EnvironmentObject var state: AppState
    @EnvironmentObject var health: HealthService
    @EnvironmentObject var calendar: CalendarService
    private var value: Double? {
        switch card.id { case .steps: return health.steps; case .sleep: return health.sleep; case .heart: return health.heart; case .workouts: return health.workoutMinutes; default: return nil }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardHeading(card: card, subtitle: card.id == .sleep ? state.copy("Letzte Nacht", "Cette nuit", "Last night") : state.copy("Heute", "Aujourd’hui", "Today"))
            if card.id == .calendar { calendarBody }
            else if !health.requested {
                Label(state.copy("Apple Health verbinden", "Connecter Apple Santé", "Connect Apple Health"), systemImage: "heart.text.square").font(.title3.weight(.semibold))
                Text(state.copy("Tippe für deine Freigaben und Details.", "Touche pour les autorisations et détails.", "Tap for permissions and details.")).font(.subheadline).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        MetricHeadline(value: value, card: card)
                        if card.id == .heart, let date = health.heartUpdated {
                            Text(date, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(.secondary)
                        } else if let goal = card.goal, card.presentation == .ring {
                            Text(state.copy("von ", "sur ", "of ") + metricText(goal, kind: card.id)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if card.presentation == .ring { GoalRing(value: value, goal: card.goal, color: card.accent) }
                    else if card.presentation == .value { Image(systemName: card.id.symbol).font(.system(size: 44)).foregroundStyle(card.accent.opacity(0.25)).accessibilityHidden(true) }
                }
                if value == nil { Text(state.copy.missing).font(.caption).foregroundStyle(.secondary) }
                if card.id != .sleep && (card.presentation == .bars || card.presentation == .line || card.size == .large) {
                    MetricChart(points: card.id == .heart ? health.heartToday : health.weekly[card.id] ?? [], card: card, compact: true, selected: .constant(nil))
                    Text(card.id == .heart ? state.copy("Heute · stündlicher Durchschnitt", "Aujourd’hui · moyenne horaire", "Today · hourly average") : state.copy("Diese Woche", "Cette semaine", "This week")).font(.caption2).foregroundStyle(.secondary)
                }
                if card.id == .sleep { Text(state.copy("Schlafdauer im Verhältnis zu deinem Ziel · keine Bewertung der Schlafqualität", "Durée par rapport à ton objectif · pas une évaluation de la qualité", "Duration relative to your goal · not a sleep quality score")).font(.caption).foregroundStyle(.secondary) }
                if card.size == .large {
                    Divider()
                    Label(state.copy("Verläufe und frühere Werte ansehen", "Voir les tendances et valeurs passées", "Explore history and earlier values"), systemImage: "clock.arrow.circlepath").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.modifier(CardPanel(card: card))
    }
    private var upcoming: [CalendarItem] { Array(events.filter { $0.end >= Date() }.prefix(card.size == .small ? 1 : card.size == .medium ? 3 : 5)) }
    @ViewBuilder private var calendarBody: some View {
        HStack {
            ForEach(0..<7, id: \.self) { offset in
                let day = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
                VStack(spacing: 8) {
                    Text(day, format: .dateTime.weekday(.narrow)).font(.caption2).foregroundStyle(.secondary)
                    Text(day, format: .dateTime.day()).font(.subheadline.bold()).frame(width: 30, height: 30).background(offset == 0 ? card.accent : .clear, in: Circle()).foregroundStyle(offset == 0 ? .white : .primary)
                    Circle().fill(events.contains { Calendar.current.isDate($0.start, inSameDayAs: day) } ? card.accent : .clear).frame(width: 4, height: 4)
                }.frame(maxWidth: .infinity)
            }
        }
        if !calendar.hasAccess && events.isEmpty {
            Label(state.copy("Kalender verbinden", "Connecter les calendriers", "Connect calendars"), systemImage: "calendar.badge.plus").font(.title3.weight(.semibold))
            Text(state.copy("Deine Termine, an einem Ort. Tippe für Details.", "Tes événements réunis. Touche pour les détails.", "Your events in one place. Tap for details.")).font(.subheadline).foregroundStyle(.secondary)
        } else if upcoming.isEmpty {
            Label(state.copy("Platz für dich", "Du temps pour toi", "Room for you"), systemImage: "leaf").font(.title2.bold())
            Text(state.copy("Keine anstehenden Termine in den nächsten 7 Tagen.", "Aucun événement dans les 7 prochains jours.", "No upcoming events in the next 7 days.")).font(.subheadline).foregroundStyle(.secondary)
        } else {
            ForEach(upcoming) { event in
                EventRow(event: event, color: card.accent)
            }
        }
    }
    private var nextDays: [MetricPoint] {
        let cal = Calendar.current, start = cal.startOfDay(for: Date())
        return (0..<7).map { index in
            let day = cal.date(byAdding: .day, value: index, to: start)!, end = cal.date(byAdding: .day, value: index + 1, to: start)!
            return .init(date: day, end: end, value: Double(events.filter { $0.start < end && $0.end > day }.count))
        }
    }
}
struct EventRow: View {
    let event: CalendarItem
    let color: Color
    @EnvironmentObject var state: AppState
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(event.start, format: .dateTime.day()).font(.system(.title2, design: .rounded, weight: .bold))
                Text(event.start, format: .dateTime.month(.abbreviated)).font(.caption2)
            }.foregroundStyle(color).frame(width: 46).padding(.vertical, 7).background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title).font(.subheadline.weight(.semibold)).lineLimit(3)
                Text(event.source).font(.caption).foregroundStyle(.secondary)
                if event.allDay { Text(state.copy("Ganztägig", "Toute la journée", "All day")).font(.caption).foregroundStyle(color) }
                else { Text(event.start, format: .dateTime.hour().minute()).font(.caption.weight(.semibold)).foregroundStyle(color) }
            }
            Spacer(minLength: 0)
        }.accessibilityElement(children: .combine)
    }
}

struct CardCustomizationView: View {
    let kind: CardKind
    var embedded = false
    @EnvironmentObject var state: AppState
    @EnvironmentObject var cloud: CloudService
    @EnvironmentObject var purchases: PurchaseService
    @EnvironmentObject var calendar: CalendarService
    @Environment(\.dismiss) private var dismiss
    @State private var pro = false
    private var card: DashboardCard { state.configuration.cards.first { $0.id == kind } ?? .init(id: kind) }
    private var previewCard: DashboardCard { var result = card; if !purchases.isPro { result.size = .medium }; return result }
    private func binding<T>(_ key: WritableKeyPath<DashboardCard, T>) -> Binding<T> {
        Binding(get: { card[keyPath: key] }, set: { value in
            guard let index = state.configuration.cards.firstIndex(where: { $0.id == kind }) else { return }
            state.configuration.cards[index][keyPath: key] = value; state.changed(cloud: cloud)
        })
    }
    var body: some View {
        Group {
            if embedded { form }
            else { NavigationStack { form } }
        }
    }
    private var form: some View {
            Form {
                Section(state.copy("Live-Vorschau", "Aperçu en direct", "Live preview")) {
                    VStack(spacing: 10) {
                        CardRegistry.render(card: previewCard, events: calendar.events)
                        if kind == .weather { WeatherCredits().padding(.horizontal, 12) }
                    }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section(state.copy("Darstellung", "Présentation", "Display")) {
                    Picker(state.copy("Ansicht", "Vue", "View"), selection: binding(\.presentation)) { ForEach(kind.presentations, id: \.self) { Text(state.copy.title($0)).tag($0) } }.accessibilityIdentifier("card-presentation")
                    Picker(state.copy("Hintergrund", "Fond", "Background"), selection: binding(\.surface)) { ForEach(CardSurface.allCases, id: \.self) { Text(state.copy.title($0)).tag($0) } }.pickerStyle(.segmented)
                }
                Section(state.copy("Farbe", "Couleur", "Color")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 75))], spacing: 14) {
                        ForEach(CardTint.allCases, id: \.self) { tint in
                            Button { binding(\.tint).wrappedValue = tint } label: {
                                VStack(spacing: 6) {
                                    Circle().fill(DashboardCard(id: kind, tint: tint).accent).frame(width: 34, height: 34)
                                        .overlay { if card.tint == tint { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } }
                                    Text(state.copy.title(tint)).font(.caption2).foregroundStyle(.primary)
                                }.frame(minWidth: 64, minHeight: 62)
                            }.buttonStyle(.plain).accessibilityLabel(state.copy.title(tint)).accessibilityAddTraits(card.tint == tint ? .isSelected : []).accessibilityIdentifier("card-color-" + tint.rawValue)
                        }
                    }.padding(.vertical, 6)
                }
                if kind.defaultGoal != nil {
                    Section(state.copy("Dein persönliches Tagesziel", "Ton objectif quotidien", "Your daily goal")) {
                        Stepper(value: Binding(get: { card.goal ?? kind.defaultGoal! }, set: { binding(\.goal).wrappedValue = $0 }), in: goalRange, step: kind == .steps ? 500 : kind == .sleep ? 0.5 : 5) {
                            Text(metricText(card.goal, kind: kind) + " " + state.copy.unit(kind)).monospacedDigit()
                        }
                        Text(state.copy("Ein frei gewähltes Anzeigeziel, keine medizinische Empfehlung. Schlaf über dem Ziel ist nicht automatisch besser.", "Un objectif d’affichage personnel, pas un conseil médical. Dormir au-delà de l’objectif n’est pas forcément mieux.", "A personal display goal, not medical advice. Sleeping beyond the goal is not necessarily better.")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section(state.copy("Kartengröße", "Taille de carte", "Card size")) {
                    if purchases.isPro {
                        Picker(state.copy("Größe", "Taille", "Size"), selection: binding(\.size)) { ForEach(CardSize.allCases, id: \.self) { Text(state.copy.size($0)).tag($0) } }.pickerStyle(.segmented)
                    } else { Button(state.copy("Weitere Größen mit Pro", "Plus de tailles avec Pro", "More sizes with Pro")) { pro = true } }
                }
            }.navigationTitle(state.copy.card(kind)).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(state.copy("Fertig", "Terminé", "Done")) { dismiss() } } }
                .sheet(isPresented: $pro) { ProView() }
    }
    private var goalRange: ClosedRange<Double> { kind == .steps ? 1000...40000 : kind == .sleep ? 4...12 : 5...240 }
}
