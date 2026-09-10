import SwiftUI
import StoreKit
import AuthenticationServices

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var health: HealthService
    @EnvironmentObject var cloud: CloudService
    @EnvironmentObject var purchases: PurchaseService
    @AppStorage("shareCalendarWithWidget") var shareWidget = false
    @State var auth = false
    @State var pro = false
    @State var delete = false
    @State var busy = false
    var body: some View {
        NavigationStack {
            Form {
                Section(state.copy("Dein Konto", "Ton compte", "Your account")) {
                    if let session = cloud.session {
                        Text(session.user.email ?? "Rundum")
                        Button(state.copy("Jetzt synchronisieren", "Synchroniser maintenant", "Sync now")) { Task { await state.synchronize(cloud: cloud) } }.disabled(state.syncing)
                        Button(state.copy("Abmelden", "Se déconnecter", "Sign out")) { Task { busy = true; await cloud.signOut(); busy = false } }.disabled(busy)
                        Button(state.copy("Konto löschen", "Supprimer le compte", "Delete account"), role: .destructive) { delete = true }.disabled(busy)
                    } else {
                        Text(state.copy("Du nutzt Rundum lokal.", "Tu utilises Rundum en local.", "You’re using Rundum locally."))
                        Button(state.copy("Anmelden für Sync & Familie", "Se connecter pour synchroniser et partager", "Sign in for sync & family")) { auth = true }
                    }
                    if let error = state.syncError { Notice(text: error) }
                    if let error = cloud.error { Notice(text: error) }
                }
                Section(state.copy("Sprache", "Langue", "Language")) { Picker(state.copy("Sprache", "Langue", "Language"), selection: $state.language) { ForEach(Language.allCases) { Text($0.title).tag($0) } } }
                Section(state.copy("Darstellung", "Apparence", "Appearance")) {
                    Picker(state.copy("Design", "Thème", "Theme"), selection: $state.appearance) {
                        ForEach(AppAppearance.allCases) { Text(state.copy.title($0)).tag($0) }
                    }
                    Text(state.copy("„Automatisch“ folgt der Hell-/Dunkel-Einstellung deines iPhones.", "« Automatique » suit le réglage clair/sombre de ton iPhone.", "“Automatic” follows your iPhone’s light/dark setting.")).font(.footnote).foregroundStyle(.secondary)
                }
                Section(state.copy("Kalenderquellen", "Sources de calendrier", "Calendar sources")) {
                    if calendar.hasAccess {
                        ForEach(calendar.calendars, id: \.calendarIdentifier) { source in Toggle(source.title, isOn: Binding(get: { calendar.isSelected(source.calendarIdentifier) }, set: { calendar.toggle(source.calendarIdentifier, enabled: $0) })) }
                    } else { Button(state.copy("Kalender verbinden", "Connecter les calendriers", "Connect calendars")) { Task { await calendar.request() } } }
                    Text(state.copy("Google-Kalender zuerst in den iOS-Kalendereinstellungen hinzufügen. Private Termine werden nicht hochgeladen. Gemeinsame Termine erstellst du unter „Gemeinsam“.", "Ajoute d’abord Google dans les réglages Calendrier d’iOS. Les rendez-vous privés ne sont pas envoyés au serveur. Crée les événements partagés dans « Ensemble ».", "Add Google calendars in iOS Calendar settings first. Private events are not uploaded. Create shared events in Together.")).font(.footnote).foregroundStyle(.secondary)
                }
                Section(state.copy("Privatsphäre", "Confidentialité", "Privacy")) {
                    Button(state.copy("Apple Health verbinden", "Connecter Apple Santé", "Connect Apple Health")) { Task { await health.request() } }
                    Text(state.copy("Schritte, Schlaf, Puls und Workouts werden nur lokal gelesen. Rundum bietet kein Teilen von Gesundheitsdaten an. Zugriffe kannst du in Apple Health widerrufen.", "Les pas, le sommeil, le pouls et les entraînements sont lus uniquement sur l’appareil. Rundum ne partage pas les données de santé. Révoque les accès dans Apple Santé.", "Steps, sleep, heart rate and workouts are read only on your device. Rundum does not share health data. Revoke access in Apple Health.")).font(.footnote)
                    Toggle(state.copy("Termintitel im Homescreen-Widget", "Titres des rendez-vous dans le widget", "Event titles in the Home Screen widget"), isOn: $shareWidget)
                        .onChange(of: shareWidget) { _ in WidgetSnapshot.publish(cards: state.configuration.visibleCards(isPro: purchases.isPro), events: calendar.events, copy: state.copy) }
                    Text(state.copy("Nur nach Aktivierung: der nächste private Termin wird in der App-Gruppe für das Widget gespeichert und ist auf dem Bildschirm sichtbar. Gesundheitsdaten werden nie ins Widget kopiert.", "Après activation : le prochain rendez-vous privé est stocké dans le groupe d’apps du widget et visible à l’écran. Aucune donnée de santé n’est copiée.", "When enabled, the next private event is stored in the widget’s app group and visible on screen. Health data is never copied to the widget.")).font(.footnote).foregroundStyle(.secondary)
                    Button(state.copy("iOS-Einstellungen öffnen", "Ouvrir les réglages iOS", "Open iOS settings")) { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                }
                Section { Button { pro = true } label: { HStack { Label("Rundum Pro", systemImage: "sparkles"); Spacer(); if purchases.isPro { Image(systemName: "checkmark.seal.fill") } } } }
                Section(state.copy("Wetter", "Météo", "Weather")) {
                    NavigationLink { WeatherLocationView() } label: { Label(state.copy("Wetterort auswählen", "Choisir le lieu météo", "Choose weather location"), systemImage: "cloud.sun") }
                }
                Section(state.copy("Rechtliches und Kontakt", "Informations légales et contact", "Legal and contact")) {
                    ForEach(LegalPage.allCases) { page in NavigationLink(page.title(state.copy)) { LegalView(page: page) } }
                    if let email = OperatorDetails.value("SUPPORT_EMAIL"), let url = URL(string: "mailto:" + email) { Link(state.copy("Support kontaktieren", "Contacter l’assistance", "Contact support"), destination: url) }
                    Text(state.copy("Persönliche Testversion. Rechtstexte und Betreiberangaben werden vor Veröffentlichung vervollständigt.", "Version de test personnelle. Textes juridiques et coordonnées seront complétés avant publication.", "Personal test version. Legal text and operator details will be completed before publication.")).font(.footnote).foregroundStyle(.secondary)
                }
                Section { Text("Rundum · 1.0").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle(state.copy.settings)
                .sheet(isPresented: $auth) { AuthView() }.sheet(isPresented: $pro) { ProView() }
                .confirmationDialog(state.copy("Konto und Cloud-Daten unwiderruflich löschen? Eigene gemeinsame Kalender werden auch für Mitglieder gelöscht.", "Supprimer définitivement le compte et les données cloud ? Tes calendriers partagés seront aussi supprimés pour les membres.", "Permanently delete your account and cloud data? Calendars you own will also be deleted for members."), isPresented: $delete, titleVisibility: .visible) {
                    Button(state.copy("Endgültig löschen", "Supprimer définitivement", "Delete permanently"), role: .destructive) {
                        Task { busy = true; defer { busy = false }; do { try await cloud.deleteAccount() } catch { cloud.error = error.localizedDescription } }
                    }
                }
        }
    }
}

struct AuthView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var cloud: CloudService
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var register = false
    @State private var busy = false
    @State private var message: String?
    @State private var setup = false
    @State private var appleNonce: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(state.copy("Ein Überblick. Auf all deinen Geräten.", "Un aperçu sur tous tes appareils.", "One overview. On all your devices.")).font(.title2.bold())
                    Text(state.copy("Deine Karten und gemeinsame Kalender werden synchronisiert. Gesundheitsdaten bleiben lokal.", "Tes cartes et calendriers partagés sont synchronisés. Les données de santé restent locales.", "Your cards and shared calendars sync. Health data stays local."))
                }
                if cloud.configured {
                    Section { NavigationLink(LegalPage.privacy.title(state.copy)) { LegalView(page: .privacy) }; NavigationLink(LegalPage.terms.title(state.copy)) { LegalView(page: .terms) } }
                    Section {
                        SignInWithAppleButton(.continue) { request in
                            do {
                                let nonce = try AppleSignInNonce.make()
                                appleNonce = nonce
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = AppleSignInNonce.hash(nonce)
                            } catch {
                                appleNonce = nil
                                message = error.localizedDescription
                            }
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                      let identityToken = credential.identityToken,
                                      let nonce = appleNonce else {
                                    message = state.copy("Apple hat keine gültigen Anmeldedaten geliefert.", "Apple n’a fourni aucune donnée de connexion valide.", "Apple did not provide valid sign-in credentials.")
                                    return
                                }
                                Task {
                                    busy = true; defer { busy = false; appleNonce = nil }
                                    do { try await cloud.signInWithApple(identityToken: identityToken, nonce: nonce); dismiss() }
                                    catch { message = error.localizedDescription }
                                }
                            case .failure(let error):
                                appleNonce = nil
                                if (error as? ASAuthorizationError)?.code != .canceled { message = error.localizedDescription }
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .disabled(busy)
                        .accessibilityIdentifier("sign-in-with-apple")
                    } footer: {
                        Text(state.copy("Nutze deine Apple-ID, um dein Rundum-Konto sicher zu erstellen oder dich anzumelden.", "Utilise ton identifiant Apple pour créer ton compte Rundum ou te connecter en toute sécurité.", "Use your Apple ID to securely create or access your Rundum account."))
                    }
                    Section(state.copy("Oder mit E-Mail", "Ou avec e-mail", "Or with email")) {
                        TextField("E-Mail", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField(state.copy("Passwort", "Mot de passe", "Password"), text: $password).textContentType(register ? .newPassword : .password)
                        Toggle(state.copy("Neues Konto erstellen", "Créer un compte", "Create an account"), isOn: $register)
                        if register { Text(state.copy("Mindestens 8 Zeichen. Bestätige anschließend deine E-Mail-Adresse.", "Au moins 8 caractères. Confirme ensuite ton adresse e-mail.", "At least 8 characters. Then confirm your email address.")).font(.footnote) }
                    }
                    Button {
                        Task {
                            busy = true; defer { busy = false }
                            do {
                                if try await cloud.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, register: register) { dismiss() }
                                else { message = state.copy("Bitte bestätige deine E-Mail und melde dich dann an.", "Confirme ton e-mail, puis connecte-toi.", "Confirm your email, then sign in."); register = false }
                            } catch { message = error.localizedDescription }
                        }
                    } label: { if busy { ProgressView() } else { Text(register ? state.copy("Konto erstellen", "Créer le compte", "Create account") : state.copy("Anmelden", "Se connecter", "Sign in")) } }.disabled(busy || !email.contains("@") || password.count < (register ? 8 : 1))
                } else {
                    Notice(text: state.copy("Die Cloud ist für diese App-Version noch nicht eingerichtet. Du kannst das Dashboard und deine lokalen Daten bereits nutzen.", "Le cloud n’est pas encore configuré pour cette version. Le tableau de bord et les données locales sont disponibles.", "Cloud service hasn’t been configured for this build. Your dashboard and local data are already available."))
                    Button(state.copy("Anmeldung einrichten", "Configurer la connexion", "Set up sign-in")) { setup = true }.accessibilityIdentifier("cloud-setup")
                }
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle(state.copy("Willkommen", "Bienvenue", "Welcome"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(state.copy.cancel) { dismiss() } }
                    if cloud.configured { ToolbarItem(placement: .confirmationAction) { Button { setup = true } label: { Image(systemName: "gearshape") }.accessibilityLabel(state.copy("Cloud-Verbindung ändern", "Modifier la connexion cloud", "Change cloud connection")) } }
                }
                .sheet(isPresented: $setup) { CloudSetupView() }
        }
    }
}

struct CloudSetupView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var cloud: CloudService
    @Environment(\.dismiss) private var dismiss
    @State private var projectURL = ""
    @State private var publicKey = ""
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(state.copy("Einmalige Cloud-Einrichtung", "Configuration cloud unique", "One-time cloud setup"), systemImage: "person.crop.circle.badge.plus").font(.headline)
                    Text(state.copy("Danach kannst du Konten erstellen, dich anmelden und gemeinsame Kalender verwenden.", "Tu pourras ensuite créer un compte, te connecter et partager des calendriers.", "Afterwards you can create accounts, sign in and use shared calendars."))
                }
                Section("Supabase") {
                    TextField(state.copy("Projekt-URL", "URL du projet", "Project URL"), text: $projectURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("cloud-project-url")
                    SecureField(state.copy("Öffentlicher Schlüssel", "Clé publique", "Public key"), text: $publicKey).textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("cloud-public-key")
                    Text(state.copy("Erlaubt sind nur publishable- oder anon-Schlüssel. Ein geheimer service_role-Schlüssel wird abgelehnt und gehört niemals in die App.", "Seules les clés publishable ou anon sont autorisées. Une clé secrète service_role est refusée.", "Only publishable or anon keys are accepted. A secret service_role key is rejected and must never be put in the app.")).font(.footnote).foregroundStyle(.secondary)
                    Link(state.copy("Supabase-Projekt öffnen", "Ouvrir le projet Supabase", "Open Supabase project"), destination: URL(string: "https://supabase.com/dashboard/projects")!)
                }
                if let message { Notice(text: message) }
                Button(state.copy("Sicher speichern", "Enregistrer en sécurité", "Save securely")) {
                    do { try cloud.configure(url: projectURL, publicKey: publicKey); dismiss() }
                    catch { message = error.localizedDescription }
                }.disabled(projectURL.isEmpty || publicKey.isEmpty).accessibilityIdentifier("save-cloud-configuration")
            }.navigationTitle(state.copy("Anmeldung einrichten", "Configurer la connexion", "Set up sign-in"))
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(state.copy.cancel) { dismiss() } } }
        }
    }
}

struct ProView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var purchases: PurchaseService
    @Environment(\.dismiss) var dismiss
    @State private var buying = false
    var body: some View {
        NavigationStack {
            List {
                Section { Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(Palette.teal); Text(state.copy("Mehr Platz für deinen Alltag.", "Plus de place pour ton quotidien.", "More room for your everyday life.")).font(.largeTitle.bold()) }
                Section {
                    Label(state.copy("Alle Dashboard-Karten", "Toutes les cartes", "All dashboard cards"), systemImage: "square.grid.2x2")
                    Label(state.copy("Kleine, mittlere und große Karten", "Petites, moyennes et grandes cartes", "Small, medium and large cards"), systemImage: "rectangle.expand.vertical")
                }
                if purchases.isPro { Text(state.copy("Rundum Pro ist aktiv.", "Rundum Pro est actif.", "Rundum Pro is active.")) }
                else if let product = purchases.product {
                    Button(product.displayName + " · " + product.displayPrice + state.copy(" / Monat", " / mois", " / month")) { Task { buying = true; await purchases.buy(); buying = false } }.disabled(buying)
                    Text(state.copy("Automatisch verlängerndes Monatsabo. Verwaltung und Kündigung in den Apple-Abonnements.", "Abonnement mensuel à renouvellement automatique. Gestion et annulation dans les abonnements Apple.", "Auto-renewing monthly subscription. Manage or cancel in Apple subscriptions.")).font(.footnote)
                } else { Notice(text: state.copy("Der Kauf ist momentan nicht verfügbar.", "L’achat est indisponible pour le moment.", "Purchasing is currently unavailable.")) }
                Button(state.copy("Käufe wiederherstellen", "Restaurer les achats", "Restore purchases")) { Task { await purchases.restore() } }
                Link(state.copy("Apple-Nutzungsbedingungen", "Conditions Apple", "Apple terms of use"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text(state.copy("Datenschutz: Gesundheitsdaten bleiben lokal. Konten, Dashboard-Konfiguration und ausdrücklich gemeinsam erstellte Termine werden im konfigurierten Cloud-Dienst gespeichert. Konto-Löschung unter Einstellungen.", "Confidentialité : données de santé locales. Comptes, configuration et événements explicitement partagés sont enregistrés dans le service cloud configuré. Suppression du compte dans les réglages.", "Privacy: health data stays local. Accounts, dashboard configuration and explicitly shared events are stored in the configured cloud service. Delete your account in Settings.")).font(.footnote)
                if let error = purchases.error { Notice(text: error) }
            }.navigationTitle("Rundum Pro").toolbar { ToolbarItem(placement: .confirmationAction) { Button(state.copy("Fertig", "Terminé", "Done")) { dismiss() } } }
                .task { await purchases.loadProduct() }
        }
    }
}
