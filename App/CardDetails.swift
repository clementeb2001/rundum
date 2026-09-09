import SwiftUI

struct PeriodControl: View {
    @Binding var period: HistoryPeriod
    @Binding var date: Date
    var allowFuture = false
    @EnvironmentObject var state: AppState
    private var range: DateInterval { period.interval(containing: date) }
    var body: some View {
        VStack(spacing: 16) {
            Picker(state.copy("Zeitraum", "Période", "Period"), selection: $period) {
                ForEach(HistoryPeriod.allCases) { Text(state.copy.title($0)).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("history-period")
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 40, height: 40) }.accessibilityLabel(state.copy("Vorheriger Zeitraum", "Période précédente", "Previous period")).accessibilityIdentifier("history-previous")
                Spacer(minLength: 0)
                VStack(spacing: 3) {
                    if period == .day { Text(date, format: .dateTime.day().month(.wide).year()) }
                    else if period == .month { Text(date, format: .dateTime.month(.wide).year()) }
                    else if period == .year { Text(date, format: .dateTime.year()) }
                    else { Text(range.start, format: .dateTime.day().month(.abbreviated)) + Text(" – ") + Text(range.end.addingTimeInterval(-1), format: .dateTime.day().month(.abbreviated).year()) }
                }.font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                Spacer(minLength: 0)
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 40, height: 40) }
                    .disabled(!allowFuture && range.end > Date()).accessibilityLabel(state.copy("Nächster Zeitraum", "Période suivante", "Next period"))
            }
            if !range.contains(Date()) { Button(state.copy("Zum aktuellen Zeitraum", "Période actuelle", "Current period")) { date = Date() }.font(.caption) }
        }
    }
    private func move(_ amount: Int) {
        if let next = Calendar.current.date(byAdding: period.component, value: amount, to: range.start) { date = next }
    }
}

struct CardDetailView: View {
    let kind: CardKind
    @EnvironmentObject var state: AppState
    @EnvironmentObject var health: HealthService
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var cloud: CloudService
    @Environment(\.scenePhase) private var phase
    @State private var period: HistoryPeriod = .week
    @State private var date = Date()
    @State private var selected: Date?
    @State private var history = HealthHistory()
    @State private var events: [CalendarItem] = []
    @State private var busy = false
    @State private var failure: String?
    @State private var customize = false
    @State private var chartStyle: CardPresentation = .bars
    private var card: DashboardCard { state.configuration.cards.first { $0.id == kind } ?? .init(id: kind) }
    private var chartCard: DashboardCard { var value = card; value.presentation = chartStyle; return value }
    private var range: DateInterval { period.interval(containing: date) }
    private var taskID: String { "\(period.rawValue)-\(date.timeIntervalSince1970)-\(health.requested)-\(calendar.hasAccess)" }
    private var points: [MetricPoint] {
        if kind != .calendar { return history.points }
        return period.buckets(containing: date).map { bucket in
            MetricPoint(date: bucket.start, end: bucket.end, value: Double(events.filter { $0.start < bucket.end && $0.end > bucket.start }.count))
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PeriodControl(period: $period, date: $date, allowFuture: kind == .calendar)
                if kind == .calendar && period != .year {
                    CalendarMonthGrid(date: $date, events: events, color: card.accent).modifier(CardPanel(card: card))
                }
                if kind != .calendar && (!health.requested || !health.available) { healthAccess }
                else if kind == .calendar && !calendar.hasAccess { calendarAccess }
                if busy { ProgressView(state.copy("Werte werden geladen …", "Chargement des valeurs…", "Loading values…")).frame(maxWidth: .infinity).padding(30) }
                else if let failure {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(state.copy("Daten konnten nicht geladen werden", "Impossible de charger les données", "Unable to load data"), systemImage: "exclamationmark.icloud")
                        Text(failure).font(.caption).foregroundStyle(.secondary)
                        Button(state.copy("Erneut versuchen", "Réessayer", "Try again")) { Task { await load() } }
                    }.modifier(CardPanel(card: card))
                } else if kind == .calendar ? calendar.hasAccess || !events.isEmpty : health.requested && health.available {
                    if kind == .calendar {
                        calendarRecords
                    } else { summaryPanel; metricRecords }
                }
                explanation
            }.padding(22).frame(maxWidth: 760)
        }.background(Palette.paper).navigationTitle(state.copy.card(kind)).navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
                Button { customize = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel(state.copy("Karte gestalten", "Personnaliser la carte", "Customize card"))
            } }
            .sheet(isPresented: $customize) { CardCustomizationView(kind: kind) }
            .task(id: taskID) { await load() }
            .onAppear { chartStyle = card.presentation == .line ? .line : .bars; if kind == .calendar { period = .month } }
            .onChange(of: phase) { phase in if phase == .active { Task { await load() } } }
            .refreshable { calendar.load(); await load() }
    }
    private var healthAccess: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(state.copy("Deine Daten bleiben bei dir", "Tes données restent privées", "Your data stays with you"), systemImage: "heart.text.square.fill").font(.headline)
            Text(state.copy("Rundum liest nur die Werte, die du in Apple Health freigibst. Fehlende Freigaben und fehlende Aufzeichnungen lassen sich nicht unterscheiden.", "Rundum lit uniquement les valeurs autorisées dans Apple Santé. Une autorisation manquante ne peut pas être distinguée d’un enregistrement absent.", "Rundum reads only values you allow in Apple Health. Missing permissions cannot be distinguished from missing recordings.")).font(.subheadline).foregroundStyle(.secondary)
            if health.available { Button(state.copy("Apple Health verbinden", "Connecter Apple Santé", "Connect Apple Health")) { Task { await health.request(); await load() } }.buttonStyle(.borderedProminent) }
        }.modifier(CardPanel(card: card))
    }
    private var calendarAccess: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(state.copy("Zeige deine aktuellen und früheren Termine aus den ausgewählten iPhone-Kalendern.", "Affiche les événements actuels et passés des calendriers iPhone sélectionnés.", "Show current and past events from your selected iPhone calendars."))
            Button(state.copy("Kalender verbinden", "Connecter les calendriers", "Connect calendars")) { Task { await calendar.request(); await load() } }.buttonStyle(.borderedProminent)
        }.modifier(CardPanel(card: card))
    }
    private var summaryTitle: String {
        if selected != nil { return state.copy("Ausgewählter Wert", "Valeur sélectionnée", "Selected value") }
        if kind == .heart { return state.copy("Ø der angezeigten Intervalle", "Moyenne des intervalles affichés", "Average of displayed intervals") }
        if kind == .sleep && period != .day { return state.copy("Ø pro erfasster Nacht", "Moyenne par nuit enregistrée", "Average per recorded night") }
        return state.copy("Im Zeitraum", "Sur cette période", "In this period")
    }
    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(summaryTitle).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            MetricHeadline(value: selected.flatMap { selection in points.first { $0.date == selection }?.value } ?? (selected == nil ? (kind == .calendar ? Double(events.count) : history.summary) : nil), card: card)
            if let selected {
                Text(selected, format: period == .day ? .dateTime.day().month().hour().minute() : .dateTime.day().month().year()).font(.caption).foregroundStyle(.secondary)
                Button(state.copy("Auswahl aufheben", "Effacer la sélection", "Clear selection")) { self.selected = nil }.font(.caption)
            }
            Picker(state.copy("Diagramm", "Graphique", "Chart"), selection: $chartStyle) {
                Text(state.copy.title(CardPresentation.bars)).tag(CardPresentation.bars)
                Text(state.copy.title(CardPresentation.line)).tag(CardPresentation.line)
            }.pickerStyle(.segmented)
            MetricChart(points: points, card: chartCard, selected: $selected)
            Text(state.copy("Tippe oder ziehe im Diagramm für einzelne Werte. Lücken bedeuten fehlende Daten.", "Touche ou glisse sur le graphique. Les espaces indiquent des données manquantes.", "Tap or drag on the chart to inspect values. Gaps mean missing data.")).font(.caption).foregroundStyle(.secondary)
        }.modifier(CardPanel(card: card))
    }
    private var calendarRecords: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(period == .year ? state.copy("Termine im Jahr", "Événements de l’année", "Events this year") : date.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.title3.bold())
            if listedEvents.isEmpty { Text(state.copy("Keine Termine. Zeit für dich.", "Aucun événement. Du temps pour toi.", "No events. Time for you.")).foregroundStyle(.secondary) }
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(listedEvents) { event in
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 3).fill(calendarSourceColor(event.source)).frame(width: 4)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(event.title).font(.headline)
                            if event.allDay { Text(state.copy("Ganztägig", "Toute la journée", "All day")).font(.subheadline) }
                            else { Text(event.start, format: .dateTime.hour().minute()) + Text(" – ") + Text(event.end, format: .dateTime.hour().minute()) }
                            Text(event.source).font(.caption).foregroundStyle(calendarSourceColor(event.source))
                            if period == .year { Text(event.start, format: .dateTime.day().month(.wide)).font(.caption) }
                        }
                        Spacer(minLength: 0)
                    }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
                    Divider()
                }
            }
        }.modifier(CardPanel(card: card))
    }
    private var listedEvents: [CalendarItem] {
        if period == .year { return events }
        let day = HistoryPeriod.day.interval(containing: date)
        return events.filter { $0.start < day.end && $0.end > day.start }
    }
    private var metricRecords: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(state.copy("Werte im Detail", "Valeurs détaillées", "Values in detail")).font(.title3.bold())
            if kind == .workouts && !history.workouts.isEmpty {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(history.workouts) { workout in
                        HStack(alignment: .top) {
                            Image(systemName: "figure.run.circle.fill").font(.title).foregroundStyle(card.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.title(state.copy)).font(.subheadline.bold())
                                Text(workout.date, format: .dateTime.day().month().hour().minute()).font(.caption)
                                Text(workout.source).font(.caption).foregroundStyle(.secondary)
                            }; Spacer(); Text(metricText(workout.minutes, kind: .workouts) + " min").font(.subheadline.bold())
                        }.accessibilityElement(children: .combine)
                        Divider()
                    }
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(points.reversed())) { point in
                        Button { selected = point.date } label: {
                            HStack {
                                Text(point.date, format: period == .day ? .dateTime.hour().minute() : period == .year ? .dateTime.month(.wide) : .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                                Spacer()
                                Text(metricText(point.value, kind: kind) + " " + state.copy.unit(kind)).monospacedDigit().foregroundStyle(point.value == nil ? Color.secondary : card.accent)
                            }.font(.subheadline).padding(.vertical, 12).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }.modifier(CardPanel(card: card))
    }
    private var explanation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(kind == .calendar ? state.copy("Aus deinen Kalendern", "Depuis tes calendriers", "From your calendars") : "Apple Health", systemImage: "lock.shield").font(.subheadline.bold())
            if kind == .calendar {
                Text(state.copy("Wähle einen Tag für deine Termine. Farben unterscheiden die Kalenderquellen. Vergangene und gemeinsame Termine erscheinen, soweit sie auf dem iPhone verfügbar oder bereits synchronisiert sind.", "Choisis un jour pour tes événements. Les couleurs distinguent les calendriers. Les événements passés et partagés dépendent des données disponibles ou déjà synchronisées.", "Choose a day to see your events. Colors distinguish calendar sources. Past and shared events depend on locally available or already synced data."))
            } else if kind == .sleep {
                Text(state.copy("Eine Nacht läuft von 12 Uhr am Vortag bis 12 Uhr am gewählten Tag. Überlappende Schlafquellen werden zusammengeführt. Im Jahr zeigt jeder Balken den Durchschnitt der erfassten Nächte dieses Monats; fehlende Nächte werden nicht als null gerechnet.", "Une nuit va de midi la veille à midi le jour choisi. Les sources qui se chevauchent sont fusionnées. Sur l’année, chaque barre est la moyenne des nuits enregistrées du mois, sans compter les nuits absentes comme zéro.", "A night runs from noon the previous day to noon on the selected day. Overlapping sources are merged. Yearly bars average the recorded nights in each month; missing nights are not counted as zero."))
            } else if kind == .heart {
                Text(state.copy("Das Diagramm zeigt Mittelwerte pro Stunde, Tag oder Monat, keine kontinuierliche Messung. Die Zusammenfassung ist der ungewichtete Durchschnitt dieser Intervalle. Kein medizinischer Befund.", "Le graphique montre des moyennes horaires, quotidiennes ou mensuelles, pas une mesure continue. Le résumé est leur moyenne non pondérée. Ce n’est pas un diagnostic.", "The chart shows hourly, daily or monthly averages, not a continuous measurement. The summary is the unweighted average of these intervals. This is not a medical finding."))
            } else {
                Text(state.copy("Stunden-, Tages- oder Monatssummen aus freigegebenen Aufzeichnungen. Trainings werden dem Startzeitpunkt zugeordnet. Fehlende Werte bedeuten nicht automatisch null. Der aktuelle Zeitraum ist noch unvollständig.", "Totaux horaires, quotidiens ou mensuels des données autorisées. Les entraînements sont affectés à leur début. Une valeur absente ne signifie pas zéro. La période actuelle est incomplète.", "Hourly, daily or monthly totals from shared recordings. Workouts are assigned to their start time. Missing values do not necessarily mean zero. The current period is still incomplete."))
            }
            if kind != .calendar { Text(state.copy("Gesundheitsverläufe bleiben im Arbeitsspeicher dieser App und werden nicht in die Rundum-Cloud hochgeladen.", "L’historique de santé reste en mémoire dans l’app, sans envoi vers le cloud Rundum.", "Health history stays in app memory and is not uploaded to Rundum cloud.")) }
        }.font(.caption).foregroundStyle(.secondary)
    }
    @State private var requestID = UUID()
    @MainActor private func load() async {
        let id = UUID(); requestID = id; busy = true; failure = nil; selected = nil; history = .init(); events = []
        defer { if requestID == id { busy = false } }
        do {
            if kind == .calendar {
                calendar.load()
                let calendarRange = kind == .calendar && period != .year ? HistoryPeriod.month.interval(containing: date) : range
                let local = calendar.history(in: calendarRange)
                let shared = cloud.events.filter { $0.starts_at < calendarRange.end && $0.ends_at > calendarRange.start }.map { event in
                    CalendarItem(id: event.id.uuidString, title: event.title, start: event.starts_at, end: event.ends_at, allDay: false, source: cloud.calendars.first { $0.id == event.calendar_id }?.name ?? "Rundum")
                }
                guard !Task.isCancelled, requestID == id else { return }
                events = (local + shared).sorted { $0.start < $1.start }
            } else {
                let result = try await health.history(kind: kind, period: period, date: date)
                guard !Task.isCancelled, requestID == id else { return }
                history = result
            }
        } catch { if !Task.isCancelled, requestID == id { failure = error.localizedDescription } }
    }
}

/// Stable colors distinguish calendar sources; they do not imply a partner is connected.
private func calendarSourceColor(_ source: String) -> Color {
    let colors: [Color] = [.blue, .purple, .orange, .teal, .pink, .indigo]
    let index = source.utf8.reduce(0) { ($0 * 31 + Int($1)) % colors.count }
    return colors[index]
}

struct CalendarMonthGrid: View {
    @Binding var date: Date
    let events: [CalendarItem]
    let color: Color
    private let calendar = Calendar.current
    private var month: DateInterval { calendar.dateInterval(of: .month, for: date)! }
    private var offset: Int { (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7 }
    private var count: Int { calendar.range(of: .day, in: .month, for: date)!.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(date, format: .dateTime.month(.wide).year()).font(.title2.bold())
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 10) {
                ForEach(0..<7, id: \.self) { index in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7]).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(0..<(offset + count), id: \.self) { index in
                    if index < offset { Color.clear.frame(height: 44) }
                    else {
                        let day = calendar.date(byAdding: .day, value: index - offset, to: month.start)!
                        let selected = calendar.isDate(day, inSameDayAs: date)
                        let interval = HistoryPeriod.day.interval(containing: day)
                        let sources = Array(Set(events.filter { $0.start < interval.end && $0.end > interval.start }.map(\.source))).sorted()
                        Button { date = day } label: {
                            VStack(spacing: 4) {
                                Text(day, format: .dateTime.day()).font(.body.weight(selected || calendar.isDateInToday(day) ? .bold : .regular)).frame(width: 34, height: 34)
                                    .background(selected ? color : .clear, in: Circle()).foregroundStyle(selected ? .white : calendar.isDateInToday(day) ? color : .primary)
                                HStack(spacing: 2) { ForEach(Array(sources.prefix(3)), id: \.self) { source in Circle().fill(calendarSourceColor(source)).frame(width: 4, height: 4) } }.frame(height: 4)
                            }.frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.plain).accessibilityLabel(day.formatted(date: .complete, time: .omitted)).accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            let sources = Array(Set(events.map(\.source))).sorted()
            if !sources.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ForEach(sources, id: \.self) { source in Label { Text(source) } icon: { Circle().fill(calendarSourceColor(source)).frame(width: 8, height: 8) }.font(.caption).padding(8).background(.quaternary, in: Capsule()) } }
                }
            }
        }.accessibilityIdentifier("calendar-month-grid")
    }
}
