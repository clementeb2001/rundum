# Prüfprotokoll · 2026-09-08

## Durchgeführt

- Xcode 26.6 / Swift 6.3.3, iOS-Mindestversion 16.0.
- Unsigned Debug-Build für iOS Simulator, arm64 und x86_64, inklusive eingebetteter WidgetKit-Erweiterung: vor Hinzufügen des App-Icon-Asset-Katalogs erfolgreich.
- Aktueller Code einschließlich Terminbearbeitung: erfolgreicher Simulator-Build mit `EXCLUDED_SOURCE_FILE_NAMES=Assets.xcassets ASSETCATALOG_COMPILER_APPICON_NAME=`. Damit sind Swift-Code, Linking und Widget-Einbettung geprüft, aber der Asset-Katalog ausdrücklich nicht.
- Der normale finale Build (Simulator und iPhone) scheitert hier beim Asset-Katalog an `No available simulator runtimes ... SimServiceContext supportedRuntimes=[]`. Auf einem Xcode mit funktionierendem Simulator-Dienst muss der vollständige Build noch bestätigt werden. Das erzeugte 1024×1024-App-Icon wurde separat angesehen; RGB-PNG ohne Alpha-Kanal.
- Swift-Package-Tests: Freemium-Limit und Erhalt des Pro-Layouts; Reihenfolge/Größen beim Codable-Roundtrip; Überlappung, Grenzen und Lücken bei Schlafintervallen; Erhalt unbekannter Karten-IDs.
- Quellcodeprüfung: ausschließlich Gesundheitsabfragen auf dem Gerät; kein Health-Datentyp in Cloud-Payloads; Refresh-Token in Keychain; private Kalender nicht im Server-Schema; Widget-Snapshot mit separater Zustimmung; RLS und geschützte RPCs im SQL enthalten.

## Nicht verifiziert

- Laufende Simulator-Oberfläche: CoreSimulatorService verweigert die Verbindung in dieser Ausführungsumgebung auch nach Freigabe der Simulator-Verzeichnisse. Es wurde keine erfolgreiche visuelle UI-Prüfung oder Simulator-Interaktion behauptet.
- HealthKit, EventKit-Berechtigungen, Widget-Verhalten und Signing auf einem realen iPhone.
- Supabase-Migration, SQL-Zugriffstests und Ende-zu-Ende-Cloud-Flows: kein Supabase-Projekt konfiguriert, keine PostgreSQL-Instanz lokal vorhanden.
- StoreKit-Käufe, Erneuerung und Widerruf: kein App-Store-Connect-Produkt konfiguriert.
- App-Store-Upload, TestFlight oder Produktionsbereitstellung.

## Manuelle Abnahme nach Einrichtung

- Alle drei Sprachen und sehr große Schrift; Navigation mit VoiceOver, Reorder-Liste und Berechtigungsdialoge.
- Onboarding ohne Konto; 0/1/2 Karten; dritte Karte kostenlos blockiert; Karten nach App-Neustart unverändert.
- Kalenderzugriff verweigert/erteilt/widerrufen; alle Quellen aus; Google-/Apple-Termine, Zeitzonen und Ganztagstermine.
- HealthKit ohne Daten, mit teilweiser Freigabe, überlappende Schlafquellen; keine fehlende Berechtigung als Messwert Null darstellen.
- Zwei Accounts: keine fremden Layouts/Termine; eigener und eingeladener Kalender; abgelaufener/verbrauchter Einladungscode; Kalender verlassen; Eigentümer-/Mitgliedsrechte bei Löschung.
- Offline Layout ändern, wieder verbinden; konkurrierende Änderungen (Last-write-wins); Konto wechseln; Konto löschen.
- Homescreen-Snapshot einschalten/ausschalten, Kalenderkarte entfernen, Termin läuft ab, App längere Zeit nicht öffnen.
- Kauf erfolgreich/abgebrochen/ausstehend, Wiederherstellung, Ablauf und Widerruf im StoreKit-Testsystem.
