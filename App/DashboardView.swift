import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var health: HealthService
    @EnvironmentObject var cloud: CloudService
    @EnvironmentObject var purchases: PurchaseService
    @State private var library = false
    @State private var dragging: CardKind?
    private var allEvents: [CalendarItem] {
        (calendar.events + cloud.events.map { event in CalendarItem(id: event.id.uuidString, title: event.title, start: event.starts_at, end: event.ends_at, allDay: false, source: cloud.calendars.first { $0.id == event.calendar_id }?.name ?? "Rundum") }).sorted { $0.start < $1.start }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { Brand(); Spacer(); Button { library = true } label: { Image(systemName: "slider.horizontal.3").padding(12).background(.background, in: Circle()) }.accessibilityLabel(state.copy("Dashboard anpassen", "Personnaliser le tableau de bord", "Customize dashboard")) }
                    VStack(alignment: .leading, spacing: 7) {
                        Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide)).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        Text(state.copy("Hallo, neuer Tag.", "Bonjour, nouvelle journée.", "Hello, new day.")).font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(state.copy("Alles Wichtige. An deinem Platz.", "L’essentiel. Au même endroit.", "Everything that matters. In your space.")).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 14) {
                        Image(systemName: "sun.horizon.fill").font(.title).foregroundStyle(Palette.peach)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(state.copy("Ein bisschen mehr Leichtigkeit.", "Un quotidien un peu plus léger.", "Make room for a lighter day.")).font(.headline)
                            Text(state.copy("Dein Überblick wächst mit dir.", "Ton aperçu évolue avec toi.", "Your overview grows with you.")).font(.subheadline).opacity(0.8)
                        }; Spacer(minLength: 0)
                    }.padding(22).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).background(Palette.teal, in: RoundedRectangle(cornerRadius: 26))
                    if let error = state.syncError { Notice(text: state.copy("Offline gespeichert. Synchronisierung ausstehend: ", "Enregistré localement. Synchronisation en attente : ", "Saved locally. Sync pending: ") + error) }
                    if state.configuration.cards.isEmpty {
                        VStack(spacing: 14) { Image(systemName: "square.grid.2x2").font(.largeTitle); Text(state.copy("Hier beginnt dein Überblick.", "Ton aperçu commence ici.", "Your overview starts here.")); Button(state.copy("Karten auswählen", "Choisir les cartes", "Choose cards")) { library = true } }.frame(maxWidth: .infinity).padding(32).background(.background, in: RoundedRectangle(cornerRadius: 24))
                    }
                    ForEach(state.configuration.visibleCards(isPro: purchases.isPro)) { card in
                        CardRegistry.render(card: card, events: allEvents)
                            .onDrag { dragging = card.id; return NSItemProvider(object: card.id.rawValue as NSString) }
                            .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                                guard !providers.isEmpty, let dragging, dragging != card.id,
                                      let from = state.configuration.cards.firstIndex(where: { $0.id == dragging }), let to = state.configuration.cards.firstIndex(where: { $0.id == card.id }) else { return false }
                                withAnimation { state.configuration.cards.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to) }
                                self.dragging = nil; state.changed(cloud: cloud); return true
                            }
                    }
                    Button { library = true } label: { Label(state.copy("Dein Dashboard gestalten", "Personnaliser ton tableau de bord", "Make this dashboard yours"), systemImage: "plus.circle").frame(maxWidth: .infinity).padding(18) }.background(Palette.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                    Text(state.copy("Gesundheitsdaten bleiben auf deinem iPhone.", "Tes données de santé restent sur ton iPhone.", "Your health data stays on your iPhone.")).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.padding(22).frame(maxWidth: 760)
            }.background(Palette.paper).toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $library) { CardLibraryView() }
                .refreshable {
                    calendar.load(); await health.load(); await state.synchronize(cloud: cloud)
                    if cloud.session != nil { do { try await cloud.loadCalendars() } catch { cloud.error = error.localizedDescription } }
                    WidgetSnapshot.publish(cards: state.configuration.visibleCards(isPro: purchases.isPro), events: calendar.events, copy: state.copy)
                }
        }
    }
}

struct DashboardCardView: View {
    let card: DashboardCard
    let events: [CalendarItem]
    @EnvironmentObject var state: AppState
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var health: HealthService
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Label(state.copy.card(card.id), systemImage: card.id.symbol).font(.headline); Spacer(); Text(card.id == .sleep ? state.copy("Letzte Nacht", "Cette nuit", "Last night") : state.copy("Heute", "Aujourd’hui", "Today")).font(.caption).foregroundStyle(.secondary) }
            if card.id == .calendar { calendarContent }
            else { healthContent }
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 26)).accessibilityElement(children: .contain)
    }
    @ViewBuilder private var calendarContent: some View {
        if !calendar.hasAccess {
            Text(state.copy("Verbinde deine Apple- und Google-Kalender auf diesem iPhone.", "Connecte tes calendriers Apple et Google présents sur cet iPhone.", "Connect the Apple and Google calendars on this iPhone.")).font(.subheadline).foregroundStyle(.secondary)
            Button(state.copy.connect) { Task { await calendar.request() } }.buttonStyle(.bordered)
        }
        if let error = calendar.error { Notice(text: error) }
        if events.isEmpty && calendar.hasAccess { Label(state.copy("Platz für das, was dir guttut. Keine anstehenden Termine in den nächsten 7 Tagen.", "Place à ce qui te fait du bien. Aucun rendez-vous dans les 7 prochains jours.", "Room for what feels good. No upcoming events in the next 7 days."), systemImage: "leaf").foregroundStyle(.secondary) }
        ForEach(Array(events.prefix(card.size == .small ? 1 : card.size == .medium ? 3 : 7))) { event in
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 2).fill(Palette.teal).frame(width: 3)
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title).font(.body.weight(.semibold))
                    Text(event.source).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    if event.allDay { Text(state.copy("Ganztägig", "Toute la journée", "All day")) } else { Text(event.start, style: .time) }
                    Text(event.start, format: .dateTime.day().month(.abbreviated)).foregroundStyle(.secondary)
                }.font(.caption)
            }.fixedSize(horizontal: false, vertical: true)
        }
    }
    private var value: Double? { switch card.id { case .steps: return health.steps; case .sleep: return health.sleep; case .heart: return health.heart; case .workouts: return health.workoutMinutes; default: return nil } }
    private var unit: String {
        switch card.id { case .steps: return state.copy("Schritte", "pas", "steps"); case .sleep: return state.copy("Stunden", "heures", "hours"); case .heart: return "bpm"; case .workouts: return "min"; default: return "" }
    }
    @ViewBuilder private var healthContent: some View {
        if !health.available { Text(state.copy("Apple Health ist auf diesem Gerät nicht verfügbar.", "Apple Santé n’est pas disponible sur cet appareil.", "Apple Health is unavailable on this device.")).foregroundStyle(.secondary) }
        else if !health.requested {
            Text(state.copy("Deine Gesundheit. Nur für dich. Du entscheidest, welche Daten Rundum lesen darf.", "Ta santé, pour toi. Choisis les données accessibles à Rundum.", "Your health, just for you. Choose which data Rundum may read.")).font(.subheadline).foregroundStyle(.secondary)
            Button(state.copy("Apple Health verbinden", "Connecter Apple Santé", "Connect Apple Health")) { Task { await health.request() } }.buttonStyle(.bordered)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value.map { $0.formatted(.number.precision(.fractionLength(card.id == .sleep ? 1 : 0))) } ?? "—").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(Palette.teal)
                Text(unit).foregroundStyle(.secondary)
            }.accessibilityElement(children: .combine)
            if value == nil {
                Text(state.copy.missing).font(.subheadline).foregroundStyle(.secondary)
                if card.size != .small { Text(state.copy("Prüfe deine Freigaben in Apple Health. Fehlende Daten können auch bedeuten, dass noch nichts aufgezeichnet wurde.", "Vérifie les autorisations dans Apple Santé. Il se peut aussi qu’aucune donnée n’ait encore été enregistrée.", "Check permissions in Apple Health. Missing data can also mean nothing has been recorded yet.")).font(.caption).foregroundStyle(.secondary) }
            } else if card.size != .small { Label(state.copy("Aus Apple Health · lokal auf deinem Gerät", "Depuis Apple Santé · sur ton appareil", "From Apple Health · on your device"), systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary) }
        }
        if let error = health.error { Notice(text: error) }
    }
}
struct Notice: View { let text: String; var body: some View { Label(text, systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary).accessibilityElement(children: .combine) } }

struct CardLibraryView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var cloud: CloudService
    @EnvironmentObject var purchases: PurchaseService
    @Environment(\.dismiss) var dismiss
    @State var pro = false
    var body: some View {
        NavigationStack {
            List {
                Section(state.copy("Deine Karten · ziehen zum Sortieren", "Tes cartes · glisser pour trier", "Your cards · drag to reorder")) {
                    ForEach(state.configuration.cards) { card in
                        VStack(alignment: .leading) {
                            Label(state.copy.card(card.id), systemImage: card.id.symbol)
                            Picker(state.copy("Größe", "Taille", "Size"), selection: Binding(get: { purchases.isPro ? card.size : .medium }, set: { size in
                                guard purchases.isPro else { pro = true; return }
                                if let i = state.configuration.cards.firstIndex(where: { $0.id == card.id }) { state.configuration.cards[i].size = size; state.changed(cloud: cloud) }
                            })) { ForEach(CardSize.allCases, id: \.self) { Text(state.copy.size($0)).tag($0) } }.pickerStyle(.segmented)
                        }.padding(.vertical, 6)
                    }.onMove { from, to in state.configuration.cards.move(fromOffsets: from, toOffset: to); state.changed(cloud: cloud) }
                        .onDelete { offsets in state.configuration.cards.remove(atOffsets: offsets); state.changed(cloud: cloud) }
                }
                Section(state.copy("Bibliothek", "Bibliothèque", "Library")) {
                    ForEach(CardRegistry.kinds) { kind in
                        Toggle(isOn: Binding(get: { state.configuration.cards.contains { $0.id == kind } }, set: { enabled in
                            if state.configuration.setEnabled(kind, enabled: enabled, isPro: purchases.isPro) { state.changed(cloud: cloud) } else { pro = true }
                        })) { Label(state.copy.card(kind), systemImage: kind.symbol) }
                    }
                }
                if !purchases.isPro {
                    Section { Button("Rundum Pro") { pro = true }; Text(state.copy("Gratis: 2 aktive Karten. Pro: alle Karten und zusätzliche Größen.", "Gratuit : 2 cartes actives. Pro : toutes les cartes et tailles supplémentaires.", "Free: 2 active cards. Pro: all cards and extra sizes.")).font(.footnote) }
                }
            }.navigationTitle(state.copy("Dein Dashboard", "Ton tableau de bord", "Your dashboard"))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(state.copy("Fertig", "Terminé", "Done")) { dismiss() } }; ToolbarItem(placement: .navigationBarLeading) { EditButton() } }
                .sheet(isPresented: $pro) { ProView() }
        }
    }
}
