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
    @State private var name = ""
    @State private var code = ""
    @State private var invite: String?
    @State private var busy = false
    @State private var date = Date()
    @State private var activeCalendarID: UUID?
    @State private var selected: CalendarDraft?
    @State private var removing: SharedCalendar?

    private var activeCalendar: SharedCalendar? { cloud.calendars.first { $0.id == activeCalendarID } ?? cloud.calendars.first }
    private var monthRange: DateInterval { Calendar.current.dateInterval(of: .month, for: date) ?? HistoryPeriod.month.interval(containing: date) }
    private var monthID: String { "\(cloud.session?.user.id.uuidString ?? "none")-\(Calendar.current.component(.year, from: date))-\(Calendar.current.component(.month, from: date))" }
    private func isMine(_ id: UUID) -> Bool { id == cloud.session?.user.id }
    private func canEdit(_ event: SharedEvent, in calendar: SharedCalendar) -> Bool { isMine(event.created_by) || isMine(calendar.owner_id) }
    private func memberLabel(_ event: SharedEvent, _ calendar: SharedCalendar) -> String {
        isMine(event.created_by) ? state.copy("Du", "Toi", "You") : calendar.name
    }
    private func monthItems(_ calendar: SharedCalendar) -> [CalendarItem] {
        cloud.familyEvents.filter { $0.calendar_id == calendar.id }.map { event in
            CalendarItem(id: event.id.uuidString, title: event.title, start: event.starts_at, end: event.ends_at, allDay: false, source: memberLabel(event, calendar))
        }
    }
    private func dayEvents(_ calendar: SharedCalendar) -> [SharedEvent] {
        let day = HistoryPeriod.day.interval(containing: date)
        return cloud.familyEvents.filter { $0.calendar_id == calendar.id && $0.starts_at < day.end && $0.ends_at > day.start }.sorted { $0.starts_at < $1.starts_at }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Image(systemName: "person.2.fill").font(.largeTitle).foregroundStyle(Palette.teal)
                    Text(state.copy("Euer Alltag. Gemeinsam geplant.", "Votre quotidien, organisé ensemble.", "Your days. Planned together.")).font(.system(.title2, design: .rounded, weight: .bold))
                    Text(state.copy("Ein gemeinsamer Kalender für dich und deine Familie. Deine privaten Kalender bleiben privat.", "Un calendrier partagé pour toi et ta famille. Tes calendriers personnels restent privés.", "A shared calendar for you and your family. Your personal calendars stay private.")).font(.subheadline).foregroundStyle(.secondary)
                }
                if cloud.session == nil { signedOutSection }
                else if let active = activeCalendar {
                    if cloud.calendars.count > 1 {
                        Picker(state.copy("Kalender", "Calendrier", "Calendar"), selection: Binding(get: { active.id }, set: { activeCalendarID = $0 })) {
                            ForEach(cloud.calendars) { Text($0.name).tag($0.id) }
                        }
                    }
                    Section(active.name) {
                        CalendarMonthGrid(date: $date, events: monthItems(active), color: Palette.teal)
                            .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                    }
                    Section {
                        let events = dayEvents(active)
                        if events.isEmpty {
                            Label(state.copy("Keine Termine an diesem Tag.", "Aucun événement ce jour-là.", "No events on this day."), systemImage: "calendar").foregroundStyle(.secondary)
                        } else {
                            ForEach(events) { event in eventRow(event, active) }
                        }
                        Button { selected = .init(calendar: active, day: date) } label: {
                            Label(state.copy("Termin hinzufügen", "Ajouter un événement", "Add event"), systemImage: "plus.circle.fill")
                        }.accessibilityIdentifier("family-add-event")
                    } header: { Text(date, format: .dateTime.weekday(.wide).day().month(.wide)) }

                    shareSection(active)
                    manageSection(owning: cloud.calendars.contains { isMine($0.owner_id) })
                    Section {
                        Button(isMine(active.owner_id) ? state.copy("Kalender löschen", "Supprimer le calendrier", "Delete calendar") : state.copy("Kalender verlassen", "Quitter le calendrier", "Leave calendar"), role: .destructive) { removing = active }
                    }
                } else {
                    Section {
                        Label(state.copy("Noch kein gemeinsamer Kalender", "Pas encore de calendrier partagé", "No shared calendar yet"), systemImage: "calendar.badge.plus").font(.headline)
                        Text(state.copy("Erstelle einen Kalender und lade deine Freundin oder Familie ein – oder tritt mit einem Einladungscode bei.", "Crée un calendrier et invite ta partenaire ou ta famille – ou rejoins avec un code.", "Create a calendar and invite your partner or family – or join with an invitation code.")).font(.subheadline).foregroundStyle(.secondary)
                    }
                    manageSection(owning: false)
                }
                if busy { ProgressView() }
                if let error = cloud.error { Notice(text: error) }
            }
            .navigationTitle(state.copy("Gemeinsam", "Ensemble", "Together"))
            .sheet(isPresented: $auth) { AuthView() }
            .sheet(item: $selected, onDismiss: { Task { await reloadMonth() } }) { draft in EventComposer(draft: draft) }
            .task(id: monthID) { await reloadMonth() }
            .refreshable { await reloadMonth() }
            .confirmationDialog(state.copy("Kalender entfernen? Als Eigentümer löschst du ihn samt Terminen für alle Mitglieder.", "Retirer le calendrier ? En tant que propriétaire, tu le supprimes avec ses événements pour tous les membres.", "Remove calendar? As owner, this deletes it and its events for all members."), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                Button(state.copy("Entfernen", "Retirer", "Remove"), role: .destructive) { if let calendar = removing { perform { try await cloud.leaveCalendar(calendar); try await cloud.loadFamilyEvents(in: monthRange) } }; removing = nil }
            }
        }
    }

    @ViewBuilder private var signedOutSection: some View {
        Section {
            Label(cloud.configured ? state.copy("Bereit für Anmeldung", "Prêt pour la connexion", "Ready for sign-in") : state.copy("Einrichtung erforderlich", "Configuration requise", "Setup required"), systemImage: cloud.configured ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundColor(cloud.configured ? Palette.teal : Color.secondary)
            Text(cloud.configured ? state.copy("Melde dich mit deiner Apple-ID an, um einen gemeinsamen Kalender zu nutzen.", "Connecte-toi avec ton identifiant Apple pour utiliser un calendrier partagé.", "Sign in with your Apple ID to use a shared calendar.") : state.copy("Verbinde zuerst einmalig ein Supabase-Projekt. Dein lokales Dashboard funktioniert weiterhin ohne Konto.", "Connecte d’abord un projet Supabase. Ton tableau de bord local reste disponible sans compte.", "First connect a Supabase project once. Your local dashboard keeps working without an account.")).font(.subheadline).foregroundStyle(.secondary)
            Button(cloud.configured ? state.copy("Anmelden oder Konto erstellen", "Connexion ou création de compte", "Sign in or create account") : state.copy("Anmeldung einrichten", "Configurer la connexion", "Set up sign-in")) { auth = true }.accessibilityIdentifier("family-auth")
        }
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

    @ViewBuilder private func shareSection(_ calendar: SharedCalendar) -> some View {
        Section(state.copy("Teilen & Mitglieder", "Partage et membres", "Sharing & members")) {
            if isMine(calendar.owner_id) {
                Button { perform { invite = try await cloud.invite(calendar: calendar.id) } } label: {
                    Label(state.copy("Zum Kalender einladen", "Inviter au calendrier", "Invite to calendar"), systemImage: "person.badge.plus")
                }.accessibilityIdentifier("family-invite")
            }
            if let invite {
                let message = state.copy(
                    "Tritt meinem gemeinsamen Rundum-Kalender bei. Öffne Rundum → Gemeinsam → „Einladung annehmen“ und gib diesen Code ein:\n\n\(invite)",
                    "Rejoins mon calendrier Rundum partagé. Ouvre Rundum → Ensemble → « Accepter une invitation » et saisis ce code :\n\n\(invite)",
                    "Join my shared Rundum calendar. Open Rundum → Together → “Accept invitation” and enter this code:\n\n\(invite)")
                ShareLink(item: message) { Label(state.copy("Einladung teilen", "Partager l’invitation", "Share invitation"), systemImage: "square.and.arrow.up") }
                Text(invite).font(.system(.footnote, design: .monospaced)).textSelection(.enabled).foregroundStyle(.secondary)
                Text(state.copy("Einmaliger Code · 7 Tage gültig. Ein neuer Code ersetzt den vorherigen.", "Code à usage unique · valable 7 jours. Un nouveau code remplace le précédent.", "One-use code · valid for 7 days. A new code replaces the previous one.")).font(.footnote).foregroundStyle(.secondary)
            }
            Text(state.copy("Alle Mitglieder melden sich mit ihrer Apple-ID an und sehen und bearbeiten dieselben Termine. Teile die Einladung z. B. per Nachrichten oder WhatsApp.", "Chaque membre se connecte avec son identifiant Apple et voit et modifie les mêmes événements. Partage l’invitation par Messages ou WhatsApp.", "Every member signs in with their Apple ID and sees and edits the same events. Share the invitation via Messages or WhatsApp.")).font(.footnote).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func manageSection(owning: Bool) -> some View {
        if !owning {
            Section(state.copy("Neuer gemeinsamer Kalender", "Nouveau calendrier partagé", "New shared calendar")) {
                TextField(state.copy("Zum Beispiel: Familie", "Par exemple : Famille", "For example: Family"), text: $name)
                Button(state.copy("Kalender erstellen", "Créer le calendrier", "Create calendar")) { perform { try await cloud.createCalendar(name: name.trimmingCharacters(in: .whitespacesAndNewlines)); name = ""; try await cloud.loadFamilyEvents(in: monthRange) } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
            }
        }
        Section(state.copy("Einladung annehmen", "Accepter une invitation", "Accept invitation")) {
            TextField(state.copy("Einladungscode", "Code d’invitation", "Invitation code"), text: $code).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button(state.copy("Beitreten", "Rejoindre", "Join")) { perform { try await cloud.join(code: code); code = ""; try await cloud.loadFamilyEvents(in: monthRange) } }.disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
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
