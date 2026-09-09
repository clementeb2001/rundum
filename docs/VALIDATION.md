# Prüfprotokoll · 2026-09-08

## Nachtrag 2026-09-09: Karten, Personalisierung und Detailseiten

- Vollständiger Simulator-Build mit den neuen Karten, Swift Charts, Detailseiten und UI-Testtarget erfolgreich; auch der unsigned iPhone-Hardware-Build mit dem Schema „Rundum Device“ ist erfolgreich.
- Alle elf Core-Tests bestehen: bestehende Kartenkonfigurationen, Freemium-Erhalt, Farb-/Darstellungs-Persistenz, unbekannte Optionen, fehlende Messwerte, Zielringe, Schlafüberschneidungen, Sommer-/Winterzeit und Schaltjahr.
- Alle vier Bedienungstests auf einem eigenen iPhone-Simulator bestehen: Kalenderdetails und Zeitraumwechsel, Health-Berechtigungszustand ohne erfundene Werte, Personalisierung über App-Neustarts sowie Wetteraktivierung, Wetterdetails und der leere Verlauf des noch laufenden Tages. Der Wettertest stellt anschließend die ursprüngliche Kartenauswahl wieder her. Screenshots von Kalenderdetails und Personalisierung wurden visuell geprüft.
- Projektgenerator in einer temporären Kopie ausgeführt: gültiges Xcode-Projekt, alle vier vorhandenen Team-Einstellungen bleiben erhalten. Das aktive Projekt wurde nicht neu generiert.
- Noch offen: reale HealthKit-Verläufe und signierte WeatherKit-Abfragen einschließlich historischer Temperaturen auf dem persönlichen iPhone, umfassende Prüfung mit großer Schrift/VoiceOver und allen Sprachen. Der neue Kartenstand wurde noch nicht auf dem persönlichen iPhone installiert. Die unten bestätigte Geräteinstallation betrifft den vorherigen Stand.

## Nachtrag: Installation auf dem persönlichen iPhone

- Das persönliche iPhone wurde in Xcode als Testgerät registriert. Xcode hat die verwalteten Entwicklungsprofile für App und Widget erfolgreich bereitgestellt.
- Nach den vom Nutzer bestätigten macOS-Schlüsselbund-Abfragen wurde Rundum auf dem iPhone installiert. Die gezielte Geräteabfrage bestätigte am 08.09.2026 um 19:53 Uhr `app.rundum.ios`, Version 1.0, Build 1.
- Damit ist die Geräteinstallation bestätigt. Ein vollständiger Funktionstest mit realen HealthKit- und WeatherKit-Daten ist damit noch nicht nachgewiesen. Die älteren Aussagen zur fehlenden Geräteinstallation unten beschreiben den damaligen Stand.

## Aktualisierung: Wetter und persönlicher iPhone-Test

- Der frühere CoreSimulator-Fehler war eine Zugriffsbeschränkung der Ausführungsumgebung. Mit passenden Rechten gelang der vollständige Simulator-Build inklusive App-Icon und Widget, und die App wurde sichtbar gestartet.
- Auch der aktuelle Simulator-Build mit WeatherKit-Karte, Ortsauswahl, Rechtsseiten, konfigurierbaren Bundle-IDs und zusätzlichem Device-Schema ist erfolgreich.
- Der aktuelle unsigned iPhone-Build (`Rundum Device`, `iphoneos`, `generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`) ist ebenfalls erfolgreich. Dies prüft Kompilierung und Verpackung für iPhone-Hardware, aber noch keine Signierung oder Installation auf dem Gerät.
- Die neue Wetterkarte wurde über die Bibliothek aktiviert. Die Ortsauswahl mit Luxemburg und weiteren Städten öffnet sich korrekt; ohne WeatherKit-Freischaltung werden fehlgeschlagene Abrufe sichtbar mit Wiederholungsmöglichkeit dargestellt. Alle vier bestehenden Core-Tests bestehen weiterhin.
- Reale WeatherKit-Anfragen benötigen aktivierte App-ID und passende Signierung. HealthKit, WeatherKit und Installation auf dem persönlichen iPhone sind noch nicht auf echter Hardware bestätigt: `devicectl list devices` meldete kein angeschlossenes Gerät.
- Betreiberangaben werden auf ausdrücklichen Wunsch erst später ergänzt. Rechtsseiten sind Testentwürfe; Supabase bleibt unkonfiguriert. Kein Produktionsstatus wird behauptet.

Die nachfolgenden Einträge dokumentieren den ursprünglichen Build-Verlauf und werden durch diese Aktualisierung ergänzt.

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
