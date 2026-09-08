import SwiftUI

enum Language: String, CaseIterable, Identifiable {
    case de, fr, en
    var id: String { rawValue }
    var title: String { switch self { case .de: return "Deutsch"; case .fr: return "Français"; case .en: return "English" } }
    static var initial: Language { Language(rawValue: String(Locale.preferredLanguages.first?.prefix(2) ?? "de")) ?? .en }
}
struct Copy {
    let language: Language
    func callAsFunction(_ de: String, _ fr: String, _ en: String) -> String {
        switch language { case .de: return de; case .fr: return fr; case .en: return en }
    }
    func card(_ kind: CardKind) -> String {
        switch kind {
        case .calendar: return self("Dein Kalender", "Ton calendrier", "Your calendar")
        case .steps: return self("Bewegung", "Mouvement", "Movement")
        case .sleep: return self("Schlaf", "Sommeil", "Sleep")
        case .heart: return self("Herzfrequenz", "Fréquence cardiaque", "Heart rate")
        case .workouts: return self("Training", "Entraînement", "Workouts")
        default: return kind.rawValue
        }
    }
    var cancel: String { self("Abbrechen", "Annuler", "Cancel") }
    var save: String { self("Speichern", "Enregistrer", "Save") }
    var connect: String { self("Verbinden", "Connecter", "Connect") }
    var missing: String { self("Keine freigegebenen Daten", "Aucune donnée autorisée", "No shared data available") }
    var settings: String { self("Einstellungen", "Réglages", "Settings") }
    func size(_ size: CardSize) -> String {
        switch size { case .small: return self("Klein", "Petit", "Small"); case .medium: return self("Mittel", "Moyen", "Medium"); case .large: return self("Groß", "Grand", "Large") }
    }
}
