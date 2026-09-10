import SwiftUI

struct CalendarDraft: Identifiable {
    let calendar: SharedCalendar
    var event: SharedEvent? = nil
    var day: Date? = nil
    var id: UUID { event?.id ?? calendar.id }
}

struct FamilyView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var cloud: CloudService
    @State private var auth = false
    @State private var settings = false
    @State private var busy = false
    @State private var date = Date()
    @State private var activeCalendarID: UUID?
    @State private var selected: CalendarDraft?

    private var activeCalendar: SharedCalendar? { cloud.calendars.first { $0.id == activeCalendarID } ?? cloud.calendars.first }
    private var monthRange: DateInterval { Calendar.current.dateInterval(of: .month, for: date) ?? HistoryPeriod.month.interval(containing: date) }
    private var monthID: String { "\(cloud.session?.user.id.uuidString ?? "none")-\(Calendar.current.component(.year, from: date))-\(Calendar.current.component(.month, from: date))" }
    private func isMine(_ id: UUID) -> Bool { id == cloud.session?.user.id }
    private func canEdit(_ event: SharedEvent, in calendar: SharedCalendar) -> Bool { isMine(event.created_by) || isMine(calendar.owner_id) }
    private func memberLabel(_ event: SharedEvent, _ calendar: SharedCalendar) -> String { isMine(event.created_by) ? state.copy("Du", "Toi", "You") : calendar.name }
    private func monthItems(_ calendar: SharedCalendar) -> [CalendarItem] {
        cloud.familyEvents.filter { $0.calendar_id == calendar.id }.map { event in
            CalendarItem(id: event.id.uuidString, title: event.title, start: event.starts_at, end: event.ends_at, allDay: false, source: memberLabel(event, calendar))
        }
    }
    private func dayEvents(_ calendar: SharedCalendar) -> [SharedEvent] {
        let day = HistoryPeriod.day.interval(containing: date)
        return cloud.familyEvents.filter { $0.calendar_id == calendar.id && $0.starts_at < day.end && $0.ends_at > day.start }.sorted { $0.starts_at < $1.starts_at }
    }
    private var navTitle: String { cloud.session != nil ? (activeCalendar?.name ?? state.copy("Gemeinsam", "Ensemble", "Together")) : state.copy("Gemeinsam", "Ensemble", "Together") }

    var body: some View {
        NavigationStack {
            Group {
                if cloud.session == nil { signedOut }
                else if let active = activeCalendar { calendarView(active) }
                else { emptyState }
            }
            .navigationTitle(navTitle)
            .toolbar {
                if cloud.session != nil && activeCalendar != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { settings = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel(state.copy("Kalendereinstellungen", "Réglages du calendrier", "Calendar settings")).accessibilityIdentifier("family-settings")
                    }
                }
            }
            .sheet(isPresented: $auth) { AuthView() }
            .sheet(isPresented: $settings, onDismiss: { Task { await reloadMonth() } }) { SharedCalendarSettingsView(activeCalendarID: $activeCalendarID) }
            .sheet(item: $selected, onDismiss: { Task { await reloadMonth() } }) { draft in EventComposer(draft: draft) }
            .task(id: monthID) { await reloadMonth() }
        }
    }

    private func calendarView(_ active: SharedCalendar) -> some View {
        List {
            Section {
                CalendarMonthGrid(date: $date, events: monthItems(active), color: Palette.teal)
                    .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 12, trailing: 14))
            }
            Section {
                let events = dayEvents(active)
                if events.isEmpty {
                    Label(state.copy("Keine Termine an diesem Tag.", "Aucun événement ce jour-là.", "No events on this day."), systemImage: "sparkles").foregroundStyle(.secondary)
                } else {
                    ForEach(events) { event in eventRow(event, active) }
                }
                Button { selected = .init(calendar: active, day: date) } label: {
                    Label(state.copy("Termin hinzufügen", "Ajouter un événement", "Add event"), systemImage: "plus.circle.fill")
                }.accessibilityIdentifier("family-add-event")
            } header: { Text(date, format: .dateTime.weekday(.wide).day().month(.wide)) }
            if let error = cloud.error { Section { Notice(text: error) } }
        }.refreshable { await reloadMonth() }
    }

    private var signedOut: some View {
        centered {
            Image(systemName: "person.2.fill").font(.system(size: 46)).foregroundStyle(Palette.teal)
            Text(state.copy("Euer Alltag. Gemeinsam geplant.", "Votre quotidien, organisé ensemble.", "Your days. Planned together.")).font(.system(.title2, design: .rounded, weight: .bold)).multilineTextAlignment(.center)
            Text(cloud.configured ? state.copy("Melde dich mit deiner Apple-ID an, um einen gemeinsamen Kalender zu nutzen.", "Connecte-toi avec ton identifiant Apple pour utiliser un calendrier partagé.", "Sign in with your Apple ID to use a shared calendar.") : state.copy("Verbinde zuerst einmalig ein Supabase-Projekt. Dein lokales Dashboard funktioniert weiterhin ohne Konto.", "Connecte d’abord un projet Supabase. Ton tableau de bord local reste disponible sans compte.", "First connect a Supabase project once. Your local dashboard keeps working without an account.")).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(cloud.configured ? state.copy("Anmelden oder Konto erstellen", "Connexion ou création de compte", "Sign in or create account") : state.copy("Anmeldung einrichten", "Configurer la connexion", "Set up sign-in")) { auth = true }
                .buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("family-auth")
        }
    }

    private var emptyState: some View {
        centered {
            Image(systemName: "calendar.badge.plus").font(.system(size: 46)).foregroundStyle(Palette.teal)
            Text(state.copy("Euer gemeinsamer Kalender", "Votre calendrier partagé", "Your shared calendar")).font(.system(.title2, design: .rounded, weight: .bold)).multilineTextAlignment(.center)
            Text(state.copy("Erstelle einen Kalender und lade deine Familie ein – oder tritt mit einem Einladungscode bei.", "Crée un calendrier et invite ta famille – ou rejoins avec un code d’invitation.", "Create a calendar and invite your family – or join with an invitation code.")).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(state.copy("Kalender erstellen oder beitreten", "Créer ou rejoindre", "Create or join")) { settings = true }
                .buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("family-start")
        }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView { VStack(spacing: 18) { content() }.padding(28).frame(maxWidth: 480).frame(maxWidth: .infinity) }.background(Palette.paper)
    }

    private func eventRow(_ event: SharedEvent, _ calendar: SharedCalendar) -> some View {
        Button { if canEdit(event, in: calendar) { selected = .init(calendar: calendar, event: event) } } label: {
            HStack(alignment: .top, spacing: 11) {
                RoundedRectangle(cornerRadius: 3).fill(calendarSourceColor(memberLabel(event, calendar))).frame(width: 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title).font(.headline)
                    (Text(event.starts_at, format: .dateTime.hour().minute()) + Text(" – ") + Text(event.ends_at, format: .dateTime.hour().minute())).font(.subheadline).foregroundStyle(.secondary)
                    Text(memberLabel(event, calendar)).font(.caption).foregroundStyle(calendarSourceColor(memberLabel(event, calendar)))
                }
                Spacer(minLength: 0)
            }
        }.buttonStyle(.plain).disabled(!canEdit(event, in: calendar))
            .swipeActions {
                if canEdit(event, in: calendar) {
                    Button(role: .destructive) { perform { try await cloud.deleteEvent(event); try await cloud.loadFamilyEvents(in: monthRange) } } label: { Label(state.copy("Löschen", "Supprimer", "Delete"), systemImage: "trash") }
                }
            }
    }

    private func reloadMonth() async {
        guard cloud.session != nil else { return }
        do { try await cloud.loadFamilyEvents(in: monthRange) } catch { cloud.error = error.localizedDescription }
    }
    private func perform(_ action: @escaping () async throws -> Void) {
        guard !busy else { return }; busy = true; cloud.error = nil
        Task { defer { busy = false }; do { try await action() } catch { cloud.error = error.localizedDescription } }
    }
}

/// All management for a shared calendar lives here so the Together tab stays a clean calendar.
struct SharedCalendarSettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var cloud: CloudService
    @Environment(\.dismiss) private var dismiss
    @Binding var activeCalendarID: UUID?
    @State private var name = ""
    @State private var code = ""
    @State private var invite: String?
    @State private var busy = false
    @State private var removing: SharedCalendar?
    @State private var importTarget: SharedCalendar?

    private var active: SharedCalendar? { cloud.calendars.first { $0.id == activeCalendarID } ?? cloud.calendars.first }
    private var owningAny: Bool { cloud.calendars.contains { $0.owner_id == cloud.session?.user.id } }
    private func isMine(_ id: UUID) -> Bool { id == cloud.session?.user.id }

    var body: some View {
        NavigationStack {
            Form {
                if cloud.calendars.count > 1, let active {
                    Section(state.copy("Aktiver Kalender", "Calendrier actif", "Active calendar")) {
                        Picker(state.copy("Kalender", "Calendrier", "Calendar"), selection: Binding(get: { active.id }, set: { activeCalendarID = $0 })) {
                            ForEach(cloud.calendars) { Text($0.name).tag($0.id) }
                        }
                    }
                }
                if let active {
                    Section(state.copy("Teilen & Mitglieder", "Partage et membres", "Sharing & members")) {
                        if isMine(active.owner_id) {
                            Button { perform { invite = try await cloud.invite(calendar: active.id) } } label: {
                                Label(state.copy("Zum Kalender einladen", "Inviter au calendrier", "Invite to calendar"), systemImage: "person.badge.plus")
                            }.accessibilityIdentifier("family-invite")
                        } else {
                            Label(state.copy("Du bist Mitglied dieses Kalenders.", "Tu es membre de ce calendrier.", "You are a member of this calendar."), systemImage: "person.2.fill").foregroundStyle(.secondary)
                        }
                        if let invite {
                            let message = state.copy(
                                "Tritt meinem gemeinsamen Rundum-Kalender bei. Öffne Rundum → Gemeinsam → Einstellungen → „Einladung annehmen“ und gib diesen Code ein:\n\n\(invite)",
                                "Rejoins mon calendrier Rundum partagé. Ouvre Rundum → Ensemble → Réglages → « Accepter une invitation » et saisis ce code :\n\n\(invite)",
                                "Join my shared Rundum calendar. Open Rundum → Together → Settings → “Accept invitation” and enter this code:\n\n\(invite)")
                            ShareLink(item: message) { Label(state.copy("Einladung teilen", "Partager l’invitation", "Share invitation"), systemImage: "square.and.arrow.up") }
                            Text(invite).font(.system(.footnote, design: .monospaced)).textSelection(.enabled).foregroundStyle(.secondary)
                            Text(state.copy("Einmaliger Code · 7 Tage gültig. Ein neuer Code ersetzt den vorherigen.", "Code à usage unique · valable 7 jours. Un nouveau code remplace le précédent.", "One-use code · valid for 7 days. A new code replaces the previous one.")).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Section(state.copy("Termine importieren", "Importer des événements", "Import events")) {
                        Button { importTarget = active } label: {
                            Label(state.copy("Aus iPhone-Kalender importieren", "Importer depuis le calendrier iPhone", "Import from iPhone calendar"), systemImage: "square.and.arrow.down")
                        }.accessibilityIdentifier("family-import")
                        Text(state.copy("Kopiert Termine eines iPhone-Kalenders in diesen gemeinsamen Kalender. Apps wie SuperShift erscheinen hier, sobald sie mit dem iOS-Kalender synchronisiert sind.", "Copie les événements d’un calendrier iPhone dans ce calendrier partagé. Les apps comme SuperShift apparaissent ici dès qu’elles se synchronisent avec le calendrier iOS.", "Copies events from an iPhone calendar into this shared calendar. Apps like SuperShift appear here once they sync to the iOS calendar.")).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !owningAny {
                    Section(state.copy("Neuer gemeinsamer Kalender", "Nouveau calendrier partagé", "New shared calendar")) {
                        TextField(state.copy("Zum Beispiel: Familie", "Par exemple : Famille", "For example: Family"), text: $name)
                        Button(state.copy("Kalender erstellen", "Créer le calendrier", "Create calendar")) {
                            perform { try await cloud.createCalendar(name: name.trimmingCharacters(in: .whitespacesAndNewlines)); name = ""; activeCalendarID = cloud.calendars.first { isMine($0.owner_id) }?.id }
                        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                    }
                }
                Section(state.copy("Einladung annehmen", "Accepter une invitation", "Accept invitation")) {
                    TextField(state.copy("Einladungscode", "Code d’invitation", "Invitation code"), text: $code).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(state.copy("Beitreten", "Rejoindre", "Join")) { perform { try await cloud.join(code: code); code = "" } }.disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                }
                Section {
                    Text(state.copy("Alle Mitglieder melden sich mit ihrer Apple-ID an und sehen und bearbeiten dieselben Termine. Teile die Einladung z. B. per Nachrichten oder WhatsApp.", "Chaque membre se connecte avec son identifiant Apple et voit et modifie les mêmes événements. Partage l’invitation par Messages ou WhatsApp.", "Every member signs in with their Apple ID and sees and edits the same events. Share the invitation via Messages or WhatsApp.")).font(.footnote).foregroundStyle(.secondary)
                }
                if let active {
                    Section {
                        Button(isMine(active.owner_id) ? state.copy("Kalender löschen", "Supprimer le calendrier", "Delete calendar") : state.copy("Kalender verlassen", "Quitter le calendrier", "Leave calendar"), role: .destructive) { removing = active }
                    }
                }
                if busy { ProgressView() }
                if let error = cloud.error { Notice(text: error) }
            }
            .navigationTitle(state.copy("Kalendereinstellungen", "Réglages du calendrier", "Calendar settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(state.copy("Fertig", "Terminé", "Done")) { dismiss() } } }
            .sheet(item: $importTarget) { target in ImportEventsView(target: target) }
            .confirmationDialog(state.copy("Kalender entfernen? Als Eigentümer löschst du ihn samt Terminen für alle Mitglieder.", "Retirer le calendrier ? En tant que propriétaire, tu le supprimes avec ses événements pour tous les membres.", "Remove calendar? As owner, this deletes it and its events for all members."), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                Button(state.copy("Entfernen", "Retirer", "Remove"), role: .destructive) {
                    if let calendar = removing { perform { try await cloud.leaveCalendar(calendar); if activeCalendarID == calendar.id { activeCalendarID = nil } }; dismiss() }
                    removing = nil
                }
            }
        }
    }
    private func perform(_ action: @escaping () async throws -> Void) {
        guard !busy else { return }; busy = true; cloud.error = nil
        Task { defer { busy = false }; do { try await action() } catch { cloud.error = error.localizedDescription } }
    }
}

/// Copies events from a chosen iPhone calendar (incl. shift apps synced to iOS) into a shared calendar.
struct ImportEventsView: View {
    let target: SharedCalendar
    @EnvironmentObject var state: AppState
    @EnvironmentObject var cloud: CloudService
    @EnvironmentObject var calendar: CalendarService
    @Environment(\.dismiss) private var dismiss
    @State private var sourceID: String?
    @State private var weeks = 4
    @State private var candidates: [CalendarItem] = []
    @State private var selection: Set<String> = []
    @State private var loading = false
    @State private var busy = false
    @State private var error: String?

    private var range: DateInterval {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: weeks * 7, to: start) ?? start
        return DateInterval(start: start, end: end)
    }
    private var effectiveSource: String? { sourceID ?? calendar.calendars.first?.calendarIdentifier }
    private var reloadKey: String { "\(effectiveSource ?? "")-\(weeks)-\(calendar.hasAccess)" }

    var body: some View {
        NavigationStack {
            Form {
                Section(state.copy("Quelle", "Source", "Source")) {
                    if !calendar.hasAccess {
                        Button(state.copy("iPhone-Kalender verbinden", "Connecter le calendrier iPhone", "Connect iPhone calendar")) { Task { await calendar.request() } }
                        Text(state.copy("Erlaube Zugriff, um Termine zu importieren.", "Autorise l’accès pour importer des événements.", "Allow access to import events.")).font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Picker(state.copy("Kalender", "Calendrier", "Calendar"), selection: Binding(get: { effectiveSource ?? "" }, set: { sourceID = $0 })) {
                            ForEach(calendar.calendars, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) }
                        }
                        Picker(state.copy("Zeitraum", "Période", "Range"), selection: $weeks) {
                            Text(state.copy("2 Wochen", "2 semaines", "2 weeks")).tag(2)
                            Text(state.copy("4 Wochen", "4 semaines", "4 weeks")).tag(4)
                            Text(state.copy("8 Wochen", "8 semaines", "8 weeks")).tag(8)
                            Text(state.copy("3 Monate", "3 mois", "3 months")).tag(13)
                        }
                    }
                }
                if loading { Section { ProgressView() } }
                else if calendar.hasAccess {
                    Section {
                        if candidates.isEmpty {
                            Text(state.copy("Keine neuen Termine in diesem Zeitraum.", "Aucun nouvel événement dans cette période.", "No new events in this range.")).foregroundStyle(.secondary)
                        } else {
                            Button(selection.count == candidates.count ? state.copy("Keine auswählen", "Tout désélectionner", "Select none") : state.copy("Alle auswählen", "Tout sélectionner", "Select all")) {
                                selection = selection.count == candidates.count ? [] : Set(candidates.map(\.id))
                            }
                            ForEach(candidates) { item in
                                Toggle(isOn: Binding(get: { selection.contains(item.id) }, set: { on in if on { selection.insert(item.id) } else { selection.remove(item.id) } })) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title.isEmpty ? state.copy("(Ohne Titel)", "(Sans titre)", "(No title)") : item.title).font(.subheadline.weight(.medium))
                                        Text(item.start, format: item.allDay ? .dateTime.weekday().day().month() : .dateTime.weekday().day().month().hour().minute()).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: { Text(state.copy("Bereits vorhandene Termine werden übersprungen.", "Les événements déjà présents sont ignorés.", "Events already present are skipped.")) }
                }
                if let error { Notice(text: error) }
            }
            .navigationTitle(state.copy("Termine importieren", "Importer des événements", "Import events"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(state.copy.cancel) { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(state.copy("Importieren", "Importer", "Import") + (selection.isEmpty ? "" : " (\(selection.count))")) { runImport() }.disabled(selection.isEmpty || busy)
                }
            }
            .task(id: reloadKey) { await reload() }
        }
    }

    private func key(_ title: String, _ date: Date) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() + "|" + String(Int(date.timeIntervalSince1970 / 60))
    }
    private func reload() async {
        guard calendar.hasAccess, let source = effectiveSource else { candidates = []; selection = []; return }
        loading = true; error = nil
        defer { loading = false }
        let local = calendar.events(in: range, from: source).filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        do {
            let existing = try await cloud.fetchSharedEvents(calendar: target.id, in: range)
            let seen = Set(existing.map { key($0.title, $0.starts_at) })
            candidates = local.filter { !seen.contains(key($0.title, $0.start)) }
        } catch {
            self.error = error.localizedDescription
            candidates = local
        }
        selection = Set(candidates.map(\.id))
    }
    private func runImport() {
        guard !busy else { return }; busy = true; error = nil
        let items = candidates.filter { selection.contains($0.id) }.map { item -> (title: String, start: Date, end: Date) in
            let title = String(item.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
            let end = item.end > item.start ? item.end : item.start.addingTimeInterval(3600)
            return (title: title, start: item.start, end: end)
        }
        Task {
            defer { busy = false }
            do { try await cloud.importEvents(items, into: target.id); dismiss() }
            catch { self.error = error.localizedDescription }
        }
    }
}

struct EventComposer: View {
    let calendar: SharedCalendar
    let event: SharedEvent?
    @EnvironmentObject var state: AppState
    @EnvironmentObject var cloud: CloudService
    @Environment(\.dismiss) var dismiss
    @State var title = ""
    @State var start = Date()
    @State var end = Date().addingTimeInterval(3600)
    @State var busy = false
    @State var error: String?
    init(draft: CalendarDraft) {
        calendar = draft.calendar; event = draft.event
        // A new event on a chosen day defaults to a sensible morning slot on that day.
        let base = draft.event?.starts_at ?? draft.day.map { Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: $0) ?? $0 } ?? Date()
        _title = State(initialValue: draft.event?.title ?? "")
        _start = State(initialValue: base)
        _end = State(initialValue: draft.event?.ends_at ?? base.addingTimeInterval(3600))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section(calendar.name) {
                    TextField(state.copy("Titel", "Titre", "Title"), text: $title)
                    DatePicker(state.copy("Beginn", "Début", "Start"), selection: $start)
                    DatePicker(state.copy("Ende", "Fin", "End"), selection: $end, in: start...)
                }
                Notice(text: state.copy("Dieser Termin ist für alle Mitglieder dieses Kalenders sichtbar.", "Cet événement est visible par tous les membres du calendrier.", "This event is visible to all members of this calendar."))
                if let error { Notice(text: error) }
            }.navigationTitle(event == nil ? state.copy("Neuer Termin", "Nouvel événement", "New event") : state.copy("Termin bearbeiten", "Modifier l’événement", "Edit event"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(state.copy.cancel) { dismiss() }.disabled(busy) }
                    ToolbarItem(placement: .confirmationAction) { Button(state.copy.save) {
                        Task {
                            busy = true; defer { busy = false }
                            do {
                                let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                                if let event { try await cloud.updateEvent(event, title: cleanTitle, start: start, end: end) }
                                else { try await cloud.addEvent(calendar: calendar.id, title: cleanTitle, start: start, end: end) }
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        }
                    }.disabled(busy || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || end <= start) }
                }.onChange(of: start) { date in if end <= date { end = date.addingTimeInterval(3600) } }
        }
    }
}
