import SwiftUI

struct CalendarDraft: Identifiable {
    let calendar: SharedCalendar
    var event: SharedEvent? = nil
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
    @State private var selected: CalendarDraft?
    @State private var removing: SharedCalendar?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Image(systemName: "person.2.fill").font(.largeTitle).foregroundStyle(Palette.teal)
                    Text(state.copy("Euer Alltag. Gemeinsam geplant.", "Votre quotidien, organisé ensemble.", "Your days. Planned together.")).font(.system(.title, design: .rounded, weight: .bold))
                    Text(state.copy("Teile einen eigenen Rundum-Kalender. Deine privaten Kalender bleiben privat.", "Partage un calendrier Rundum. Tes calendriers personnels restent privés.", "Share a dedicated Rundum calendar. Your personal calendars stay private.")).foregroundStyle(.secondary)
                }
                if cloud.session == nil {
                    Section {
                        Label(cloud.configured ? state.copy("Bereit für Anmeldung", "Prêt pour la connexion", "Ready for sign-in") : state.copy("Einrichtung erforderlich", "Configuration requise", "Setup required"), systemImage: cloud.configured ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundColor(cloud.configured ? Palette.teal : Color.secondary)
                        Text(cloud.configured ? state.copy("Melde dich an oder erstelle ein Konto, um gemeinsame Kalender zu nutzen.", "Connecte-toi ou crée un compte pour partager des calendriers.", "Sign in or create an account to use shared calendars.") : state.copy("Verbinde zuerst einmalig ein Supabase-Projekt. Dein lokales Dashboard funktioniert weiterhin ohne Konto.", "Connecte d’abord un projet Supabase. Ton tableau de bord local reste disponible sans compte.", "First connect a Supabase project once. Your local dashboard keeps working without an account.")).font(.subheadline).foregroundStyle(.secondary)
                        Button(cloud.configured ? state.copy("Anmelden oder Konto erstellen", "Connexion ou création de compte", "Sign in or create account") : state.copy("Anmeldung einrichten", "Configurer la connexion", "Set up sign-in")) { auth = true }.accessibilityIdentifier("family-auth")
                    }
                } else {
                    ForEach(cloud.calendars) { calendar in
                        Section(calendar.name) {
                            ForEach(cloud.events.filter { $0.calendar_id == calendar.id }) { event in
                                Button { selected = .init(calendar: calendar, event: event) } label: {
                                    VStack(alignment: .leading, spacing: 4) { Text(event.title).font(.headline); Text(event.starts_at, format: .dateTime.weekday().day().month().hour().minute()).font(.caption).foregroundStyle(.secondary) }
                                }.buttonStyle(.plain).disabled(event.created_by != cloud.session?.user.id && calendar.owner_id != cloud.session?.user.id)
                                    .swipeActions { if event.created_by == cloud.session?.user.id || calendar.owner_id == cloud.session?.user.id { Button(role: .destructive) { perform { try await cloud.deleteEvent(event) } } label: { Label(state.copy("Löschen", "Supprimer", "Delete"), systemImage: "trash") } } }
                            }
                            Button(state.copy("Termin hinzufügen", "Ajouter un événement", "Add event")) { selected = .init(calendar: calendar) }
                            if calendar.owner_id == cloud.session?.user.id { Button(state.copy("Einladungscode erstellen", "Créer un code d’invitation", "Create invitation code")) { perform { invite = try await cloud.invite(calendar: calendar.id) } } }
                            Button(calendar.owner_id == cloud.session?.user.id ? state.copy("Kalender löschen", "Supprimer le calendrier", "Delete calendar") : state.copy("Kalender verlassen", "Quitter le calendrier", "Leave calendar"), role: .destructive) { removing = calendar }
                        }
                    }
                    Section(state.copy("Neuer gemeinsamer Kalender", "Nouveau calendrier partagé", "New shared calendar")) {
                        TextField(state.copy("Zum Beispiel: Familie", "Par exemple : Famille", "For example: Family"), text: $name)
                        Button(state.copy("Kalender erstellen", "Créer le calendrier", "Create calendar")) { perform { try await cloud.createCalendar(name: name.trimmingCharacters(in: .whitespacesAndNewlines)); name = "" } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                        Text(state.copy("In dieser Version: ein eigener gemeinsamer Kalender pro Konto.", "Dans cette version : un calendrier partagé personnel par compte.", "In this version: one owned shared calendar per account.")).font(.footnote).foregroundStyle(.secondary)
                    }
                    Section(state.copy("Einladung annehmen", "Accepter une invitation", "Accept invitation")) {
                        TextField(state.copy("Einladungscode", "Code d’invitation", "Invitation code"), text: $code).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button(state.copy("Beitreten", "Rejoindre", "Join")) { perform { try await cloud.join(code: code); code = "" } }.disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                    }
                    if let invite {
                        Section(state.copy("Einmaliger Code · 7 Tage gültig", "Code à usage unique · valable 7 jours", "One-use code · valid for 7 days")) {
                            Text(invite).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            ShareLink(item: invite) { Label(state.copy("Code teilen", "Partager le code", "Share code"), systemImage: "square.and.arrow.up") }
                            Text(state.copy("Mitglieder können Termine lesen und hinzufügen. Ein neuer Code ersetzt den vorherigen.", "Les membres peuvent lire et ajouter des événements. Un nouveau code remplace le précédent.", "Members can read and add events. A new code replaces the previous one.")).font(.footnote)
                        }
                    }
                    if busy { ProgressView() }
                    if let error = cloud.error { Notice(text: error) }
                }
            }.navigationTitle(state.copy("Gemeinsam", "Ensemble", "Together"))
                .sheet(isPresented: $auth) { AuthView() }
                .sheet(item: $selected) { draft in EventComposer(draft: draft) }
                .refreshable { if cloud.session != nil { do { try await cloud.loadCalendars() } catch { cloud.error = error.localizedDescription } } }
                .confirmationDialog(state.copy("Kalender entfernen? Als Eigentümer löschst du ihn samt Terminen für alle Mitglieder.", "Retirer le calendrier ? En tant que propriétaire, tu le supprimes avec ses événements pour tous les membres.", "Remove calendar? As owner, this deletes it and its events for all members."), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                    Button(state.copy("Entfernen", "Retirer", "Remove"), role: .destructive) { if let calendar = removing { perform { try await cloud.leaveCalendar(calendar) } }; removing = nil }
                }
        }
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
        _title = State(initialValue: draft.event?.title ?? "")
        _start = State(initialValue: draft.event?.starts_at ?? Date())
        _end = State(initialValue: draft.event?.ends_at ?? Date().addingTimeInterval(3600))
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
