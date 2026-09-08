import SwiftUI

enum LegalPage: String, Identifiable, CaseIterable {
    case imprint, privacy, terms
    var id: String { rawValue }
    func title(_ copy: Copy) -> String {
        switch self {
        case .imprint: return copy("Impressum", "Mentions légales", "Legal notice")
        case .privacy: return copy("Datenschutzerklärung", "Confidentialité", "Privacy notice")
        case .terms: return copy("Nutzungsbedingungen", "Conditions d’utilisation", "Terms of use")
        }
    }
}
enum OperatorDetails {
    static func value(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !value.contains("$(") else { return nil }
        return value
    }
    static var complete: Bool { ["OPERATOR_NAME", "OPERATOR_ADDRESS", "SUPPORT_EMAIL"].allSatisfy { value($0) != nil } }
}
struct LegalView: View {
    let page: LegalPage
    @EnvironmentObject var state: AppState
    private var c: Copy { state.copy }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Label(c("Testfassung · Stand 08.09.2026", "Version de test · 08.09.2026", "Test draft · 8 September 2026"), systemImage: "doc.text").font(.headline)
                Text(c("Für deinen persönlichen Gerätetest vorbereitet. Vor öffentlicher Nutzung müssen Betreiberangaben, tatsächlicher Cloud-Betrieb und die Rechtstexte vervollständigt und geprüft werden. Diese Fassung ist noch keine freigegebene AGB- oder Datenschutzerklärung.", "Préparé pour ton test personnel. Avant une utilisation publique, compléter et vérifier les coordonnées, le fonctionnement réel du cloud et les textes juridiques. Cette version n’est pas encore une notice juridique approuvée.", "Prepared for personal device testing. Before public use, complete and review operator details, actual cloud operations and legal text. This draft is not a finalized legal or privacy notice.")).font(.footnote).foregroundStyle(.secondary)
                if page == .imprint { imprint }
                if page == .privacy { privacy }
                if page == .terms { terms }
            }.frame(maxWidth: 700, alignment: .leading).padding(24)
        }.navigationTitle(page.title(c)).navigationBarTitleDisplayMode(.inline)
    }
    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(text).textSelection(.enabled) }
    }
    private var imprint: some View {
        VStack(alignment: .leading, spacing: 20) {
            section(c("Betreiber", "Éditeur", "Operator"), c("Privatperson mit Sitz in Luxemburg.", "Personne physique établie au Luxembourg.", "Individual based in Luxembourg."))
            section(c("Name", "Nom", "Name"), OperatorDetails.value("OPERATOR_NAME") ?? c("Vor Veröffentlichung ergänzen", "À compléter avant publication", "Complete before publication"))
            section(c("Anschrift", "Adresse", "Address"), OperatorDetails.value("OPERATOR_ADDRESS") ?? c("Vor Veröffentlichung ergänzen", "À compléter avant publication", "Complete before publication"))
            section(c("Support und Datenschutzkontakt", "Assistance et contact vie privée", "Support and privacy contact"), OperatorDetails.value("SUPPORT_EMAIL") ?? c("Vor Veröffentlichung ergänzen", "À compléter avant publication", "Complete before publication"))
        }
    }
    private var privacy: some View {
        VStack(alignment: .leading, spacing: 20) {
            section(c("Anmeldesitzung", "Session de connexion", "Sign-in session"), c("Bei späterer Cloud-Anmeldung speichert Rundum Sitzungstoken im iOS-Schlüsselbund. Diese können eine Neuinstallation überdauern. Eine Abmeldung entfernt die gespeicherte Rundum-Sitzung; die Kontolöschung entfernt zusätzlich die zugehörigen Cloud-Daten gemäß dem dann eingerichteten Backend.", "Lors d’une future connexion cloud, Rundum stocke les jetons de session dans le trousseau iOS. Ils peuvent subsister après réinstallation. La déconnexion supprime la session enregistrée ; la suppression du compte efface aussi les données cloud selon le backend configuré.", "For future cloud sign-in, Rundum stores session tokens in the iOS Keychain. These can survive reinstallation. Signing out removes the stored session; account deletion also removes associated cloud data according to the configured backend."))
            section(c("Verantwortlicher", "Responsable du traitement", "Controller"), c("Betreiber und Kontakt stehen im Impressum. Die Angaben sind für den persönlichen Test noch nicht vollständig.", "L’éditeur et le contact figurent dans les mentions légales. Ces informations sont encore incomplètes pour ce test personnel.", "Operator and contact details appear in the legal notice. They are not yet complete for this personal test."))
            section(c("Lokale Daten", "Données locales", "Local data"), c("Kartenreihenfolge, Größen, Sprache und Wetterort werden auf deinem Gerät gespeichert. Rundum liest nur nach deiner Freigabe Kalender und Apple Health. Schritte, Schlaf, Puls und Workouts werden nicht an den Rundum-Server übertragen. Die Anzeige wird im Arbeitsspeicher gehalten. Rundum enthält keine Werbe- oder Analyse-SDKs.", "L’ordre des cartes, les tailles, la langue et le lieu météo sont enregistrés sur ton appareil. Calendriers et Apple Santé sont lus après ton autorisation. Pas, sommeil, pouls et entraînements ne sont pas envoyés au serveur Rundum. L’affichage reste en mémoire. Aucun SDK publicitaire ou analytique n’est intégré.", "Card order, sizes, language and weather location are stored on your device. Calendars and Apple Health are read after permission. Steps, sleep, heart rate and workouts are not sent to a Rundum server. Display data is held in memory. No advertising or analytics SDK is included."))
            section(c("Wetter und Standort", "Météo et position", "Weather and location"), c("Für Wetter sendet WeatherKit die Koordinaten des gewählten Orts an Apple. Bei einer Ortssuche erhält Apples Geocoding-Dienst deinen Suchtext. Der aktuelle Standort wird nur nach Betätigung und iOS-Freigabe einmalig ermittelt; Rundum rundet ihn auf zwei Nachkommastellen, bevor er für Wetter verwendet und als Wetterort gespeichert wird. Keine Hintergrund-Ortung und kein Standortverlauf. Du kannst jederzeit eine Stadt auswählen.", "WeatherKit envoie à Apple les coordonnées du lieu choisi. La recherche d’un lieu transmet ton texte au service de géocodage Apple. La position actuelle n’est demandée qu’après action et autorisation iOS, une seule fois ; Rundum l’arrondit à deux décimales avant utilisation et enregistrement comme lieu météo. Aucun suivi en arrière-plan ni historique. Tu peux choisir une ville à tout moment.", "WeatherKit sends your chosen place’s coordinates to Apple. Place searches send the search text to Apple’s geocoding service. Current location is requested only after your action and iOS permission, once; Rundum rounds it to two decimal places before using and saving it as the weather location. No background tracking or location history. You can choose a city anytime."))
            section(c("Cloud und Konten", "Cloud et comptes", "Cloud and accounts"), c("In diesem Test ist noch kein Supabase-Projekt eingerichtet. Anmeldung, Sync und Familienkalender benötigen später einen konfigurierten Dienst. Dabei würden E-Mail-Adresse, Nutzer-ID, Dashboard-Konfiguration, Mitgliedschaften und ausdrücklich gemeinsam erstellte Termine verarbeitet. Vor Aktivierung müssen Anbieter, Region, Rechtsgrundlagen, Empfänger, Aufbewahrung, Backups und mögliche Drittlandübermittlungen konkret ergänzt werden.", "Aucun projet Supabase n’est configuré pour ce test. Connexion, synchronisation et calendriers partagés nécessitent un service configuré. Adresse e-mail, identifiant, configuration, adhésions et événements partagés y seraient traités. Avant activation, préciser fournisseur, région, bases légales, destinataires, conservation, sauvegardes et éventuels transferts internationaux.", "No Supabase project is configured for this test. Login, sync and shared calendars require a configured service. It would process email, user ID, dashboard configuration, memberships and explicitly shared events. Before activation, specify provider, region, legal bases, recipients, retention, backups and any international transfers."))
            section(c("Widget und Käufe", "Widget et achats", "Widget and purchases"), c("Termintitel werden nur nach separater Aktivierung in den lokalen Speicher der App-Gruppe für das Homescreen-Widget kopiert. Gesundheitsdaten nie. Testkäufe laufen lokal über Xcode. Produktive Abos würden über Apple abgewickelt; Rundum erhält keine Kreditkartendaten.", "Les titres d’événements sont copiés dans le stockage local du groupe d’apps uniquement après activation séparée du widget. Jamais les données de santé. Les achats de test sont locaux via Xcode. Les abonnements réels seraient gérés par Apple ; Rundum ne reçoit aucune donnée de carte bancaire.", "Event titles are copied to the local app-group storage only after separate widget activation. Health data is never copied. Test purchases run locally through Xcode. Live subscriptions would be handled by Apple; Rundum receives no credit-card data."))
            section(c("Kontrolle und Rechte", "Contrôle et droits", "Control and rights"), c("Freigaben kannst du in iOS bzw. Apple Health widerrufen. Den Wetterort kannst du ändern; die App-Löschung entfernt deren lokalen App-Speicher. Bei produktiver Datenverarbeitung bestehen je nach Voraussetzungen Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung, Datenübertragbarkeit, Widerspruch und Widerruf einer Einwilligung. Du kannst dich bei der luxemburgischen CNPD beschweren. Konkrete Rechtsgrundlagen und Fristen müssen vor Veröffentlichung ergänzt werden.", "Révoque les autorisations dans iOS ou Apple Santé. Tu peux changer le lieu météo ; supprimer l’app efface son stockage local. Selon les conditions applicables, tu disposes de droits d’accès, rectification, effacement, limitation, portabilité, opposition et retrait du consentement. Tu peux saisir la CNPD luxembourgeoise. Préciser les bases légales et délais avant publication.", "Revoke permissions in iOS or Apple Health. You can change the weather location; deleting the app removes its local app storage. Subject to applicable conditions, rights include access, rectification, erasure, restriction, portability, objection and withdrawal of consent. You may complain to Luxembourg’s CNPD. Specific legal bases and time limits must be completed before publication."))
            Link("CNPD · Luxembourg", destination: URL(string: "https://cnpd.public.lu/fr/particuliers/vos-droits.html")!)
            Link(c("Apple-Datenschutz", "Confidentialité Apple", "Apple privacy"), destination: URL(string: "https://www.apple.com/legal/privacy/")!)
        }
    }
    private var terms: some View {
        VStack(alignment: .leading, spacing: 20) {
            section(c("Persönlicher Test", "Test personnel", "Personal test"), c("Diese Version dient deinem privaten Funktionstest. Es werden dadurch keine kostenpflichtigen Rundum-Verträge angeboten. StoreKit-Testtransaktionen sind keine echten Zahlungen.", "Cette version sert à ton test fonctionnel privé. Aucun contrat Rundum payant n’est proposé. Les transactions StoreKit de test ne sont pas des paiements réels.", "This version is for your private functional test. It does not offer paid Rundum contracts. StoreKit test transactions are not real payments."))
            section(c("Umfang", "Fonctions", "Scope"), c("Rundum bündelt freigegebene Kalender-, Gesundheits- und Wetterinformationen. Anzeigen hängen von Freigaben, verfügbaren Daten und Diensten ab. Wetterprognosen können sich ändern; Gesundheitsanzeigen sind keine Diagnose. Prüfe wichtige Termine und Messwerte in der jeweiligen Quelle.", "Rundum regroupe les calendriers, données de santé et météo autorisés. L’affichage dépend des autorisations, données et services disponibles. Les prévisions peuvent changer ; les données de santé ne constituent pas un diagnostic. Vérifie les informations importantes dans leur source.", "Rundum combines authorized calendar, health and weather information. Displays depend on permissions, available data and services. Forecasts can change; health displays are not a diagnosis. Check important events and measurements in their source."))
            section(c("Vor Veröffentlichung", "Avant publication", "Before publication"), c("Betreiber, tatsächlicher Leistungsumfang, Preise, Laufzeiten, Kündigung, Verbraucherinformationen, anwendbare Lizenzbedingungen und Support müssen festgelegt und rechtlich geprüft werden. Gesetzliche Verbraucherrechte werden durch diesen Entwurf nicht eingeschränkt.", "L’éditeur, les prestations, prix, durées, résiliation, informations consommateurs, licences et assistance doivent être définis et vérifiés juridiquement. Ce projet ne limite aucun droit légal des consommateurs.", "Operator, actual service, prices, duration, cancellation, consumer information, licensing and support must be defined and legally reviewed. This draft does not restrict statutory consumer rights."))
            Link(c("Apple-Standardlizenz zur späteren Prüfung", "Licence standard Apple à examiner", "Apple standard license for later review"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
        }
    }
}
