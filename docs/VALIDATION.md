# Prüfprotokoll · 2026-09-08

## Design-Feinschliff, Animationen und Erscheinungsbild-Auswahl · 2026-09-10

Umsetzung der in der interaktiven Vorschau gezeigten Effekte im SwiftUI-Code sowie einer neuen Design-Einstellung. **Nicht build-verifiziert:** kein Xcode/Swift-Toolchain in dieser Linux-Umgebung; Kompilierung, Tests und visuelle Prüfung müssen in Xcode erfolgen.

- **Erscheinungsbild wählbar:** Neue Einstellung „Darstellung“ mit Hell / Dunkel / Automatisch (folgt dem iPhone). Persistiert in `UserDefaults` (`appearance`), angewendet app-weit über `.preferredColorScheme(state.appearance.colorScheme)` in `RundumApp`. `AppAppearance` in `App/Motion.swift`, lokalisierte Titel in `Copy` (de/fr/en).
- **Neue Datei `App/Motion.swift`** mit wiederverwendbaren, versionssicheren Helfern; im Xcode-Projekt (`project.pbxproj`) in allen vier Abschnitten registriert. Umgesetzte Effekte:
  1. **Rollende Zahlen** – `.contentTransition(.numericText())` (iOS 16) auf Metrik-Kennzahlen, Wetter-Temperatur, Zielring-Prozent.
  2. **Zielring füllt sich** – `GoalRing` animiert `trim` beim Erscheinen/Ändern (`.rundumRing`).
  3. **Feder-Übergänge** – Bearbeiten/Resize/Sortieren nutzen `.spring`-basierte `Animation.rundum(Snappy)` statt fester `easeInOut`.
  4. **Symbol-Effekte** – Herz `.symbolEffect(.pulse)`, Wetter `.symbolEffect(.bounce)` (iOS 17, sonst No-op).
  5. **Scroll-Reaktion** – Karten `.scrollTransition` (iOS 17, sonst No-op).
  6. **Zoom Karte→Detail** – `.matchedTransitionSource` + `.navigationTransition(.zoom)` (iOS 18, sonst normaler Push) via `@Namespace` im Dashboard.
  7. **Chart-Aufbau** – `MetricChart` skaliert/blendet beim Erscheinen ein.
  8. **Wetter-Farbverlauf** – `MeshGradient` im Wetter-`CardPanel` (iOS 18), sonst linearer Verlauf als Fallback.
  9. **Skeleton-Shimmer** – `Shimmer`-Modifier auf Health-Kennzahlen während des Ladens (iOS 16).
  10. **Haptik** – `.sensoryFeedback` bei Bearbeiten-Umschalten, Resize und Tagesauswahl (iOS 17, sonst No-op).
- **Offen (in Xcode zu prüfen):** Kompilierung aller Targets, Core-/UI-Tests, visuelle Wirkung von MeshGradient-Kontrast, Zoom-Übergang auf Gerät sowie `prefers-reduced-motion`-Verhalten. Bestehende UI-Tests referenzieren die gleichen Accessibility-IDs; keine wurden entfernt.

## Vollständige Code-Prüfung (Fehler, Sicherheit, Verbesserungen) · 2026-09-10

Statische Gesamtprüfung des Quellcodes (App, Core, Widget, Backend-SQL, Konfiguration und Projektgenerator) in der Remote-Umgebung. Kein Swift-/Xcode-Toolchain in dieser Linux-Umgebung verfügbar; Core- und UI-Tests sowie Build wurden **nicht** ausgeführt und müssen in Xcode bestätigt werden.

- **Behobener Fehler:** Das Zeichenalphabet für den Apple-Sign-in-Nonce (`Core/Models.swift`) enthielt versehentlich kein großes „W“ (`…UVXYZ…` statt Apples kanonischem `…UVWXYZ…`). Alle übrigen 25 Groß- und 26 Kleinbuchstaben waren vorhanden. Auswirkung gering (das Alphabet umfasste zufällig 64 Zeichen, wodurch die Ablehnungsauswahl unverzerrt blieb und die Entropie erhalten war); der Nonce konnte lediglich nie ein großes „W“ enthalten. Quellcode und der gespiegelte Core-Test wurden auf das vollständige Alphabet korrigiert. Nach dem Fix umfasst das Alphabet 65 Zeichen; die Ablehnungsauswahl (`byte < characters.count`) bleibt unverzerrt.
- **Sicherheit – keine Befunde:** Sitzungstoken und Cloud-Konfiguration liegen im Schlüsselbund mit `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Keine Geheimnisse im Repository; `.gitignore` deckt Schlüssel, Profile und lokale Konfiguration ab. Supabase-URL wird auf `https` und `*.supabase.co` geprüft; nur öffentliche anon-/publishable-Schlüssel werden akzeptiert, `service_role` wird abgelehnt. Apple-Sign-in nutzt gehashten Nonce an Apple und Roh-Nonce an Supabase (korrektes Muster); das Apple-ID-Passwort erreicht die App nie. Backend-RLS und `security definer`-RPCs mit `set search_path = ''` sind konsequent umgesetzt; Serverseite vertraut keinem clientseitigen Pro-Flag (ein Kalender pro Konto wird in der DB erzwungen). Wetterdiagnose gibt keine Koordinaten, Token oder Fehler-Payloads aus; Standort wird nur auf Wunsch, einmalig und auf zwei Nachkommastellen gerundet verwendet. Gesundheitsdaten verlassen das Gerät nicht.
- **Beobachtungen / Verbesserungsvorschläge (nicht geändert):**
  1. `HealthService.load()` schluckt Fehler der Einzelabfragen (`sum`/`samples`), sodass eine vorübergehende HealthKit-Störung wie „keine Daten“ (—) statt als Fehlerzustand erscheint. Bewusst gemäß Datenphilosophie, aber Störung und fehlende Aufzeichnung sind nicht unterscheidbar.
  2. `CloudService.loadCalendars()` interpoliert ISO-8601-Datumswerte ungeprüft in die PostgREST-Query. Funktioniert (UTC-`Z`, keine `+`-Offsets), Prozentkodierung wäre robuster.
  3. `CalendarService` fügt im `init` einen `NotificationCenter`-Beobachter hinzu, der nie entfernt wird; unkritisch, da das Objekt die App-Lebensdauer besitzt.
  4. Client-seitiges `isPro` steuert nur lokale UI (Kartenanzahl/-größen), keine Serverressource; serverseitig geprüfte Abos sind laut Roadmap noch offen.
  5. `Info.plist`: keine iPad-spezifischen `UISupportedInterfaceOrientations~ipad`; erklärt die dokumentierte Orientierungswarnung im Release-Build. Kein nachgewiesener Absturz.

## Native Apple-Anmeldung · 2026-09-10

- Native „Mit Apple anmelden“-Schaltfläche mit AuthenticationServices ergänzt. Ein kryptografisch sicherer Nonce wird SHA-256-gehasht an Apple übergeben; das ursprüngliche Nonce und Apples ID-Token werden anschließend direkt bei Supabase gegen eine Sitzung eingetauscht.
- Apple-Sign-in-Entitlement für das App-Target ergänzt. Die bestehende E-Mail-/Passwort-Anmeldung bleibt als Alternative erhalten; Abmeldung, Sitzungserneuerung und Kontolöschung verwenden dieselbe Supabase-Sitzung.
- Supabase-Migration nach einem teilweise ausgeführten ersten Lauf wiederholbar gemacht: Tabellen und Indexe werden nur bei Bedarf angelegt, Funktionen ersetzt und RLS-Richtlinien kontrolliert neu erstellt.
- 20 Core-Tests erfolgreich, darunter SHA-256-Testvektor und sichere Nonce-Erzeugung. Vollständiger signierter Release-Build inklusive Widget erfolgreich; die Signatur enthält das Apple-Sign-in-Entitlement. Der Build wurde auf dem verbundenen iPhone installiert und geöffnet. Der echte Apple-Dialog und abschließende Supabase-Tokenaustausch benötigen die Interaktion des Nutzers und sind noch nicht bestätigt.

## Datenzustände, Belastungstests und Anmeldung · 2026-09-10

- Health-Karten unterscheiden Laden, Fehler, fehlende Werte und letzte erfolgreiche Aktualisierung; fehlende Daten bleiben „—“ statt null. Wetter unterscheidet Laden, Verbindungsfehler und noch nicht geladene Daten.
- Schmale Leerkarten für Wetter, Kalender und Health nutzen weniger Höhe. Bestehende echte Diagramme und Ringe bleiben unverändert.
- „Gemeinsam“ zeigt klar „Einrichtung erforderlich“ oder „Bereit für Anmeldung“. Projekt-URL und ausschließlich öffentlicher Supabase-publishable/anon-Schlüssel können in der App eingegeben und im Schlüsselbund gespeichert werden. `service_role` und sonstige Schlüssel werden abgelehnt. Danach sind bestehende E-Mail-Anmeldung und Kontoerstellung erreichbar; ein echtes Projekt und das Backend-Schema sind weiterhin Voraussetzung für den Live-Betrieb.
- 18 Core-Tests erfolgreich, neu für öffentliche/geheime Cloud-Schlüssel und Termine über Mitternacht. Alle 11 UI-Tests im gemeinsamen Lauf erfolgreich, einschließlich Offline-Wetter mit Accessibility-Schrift, sicherer Cloud-Einrichtung und eines nicht fälschlich aktiv angezeigten Pro-Status.
- Signierter Release-Build inklusive Widget erfolgreich und auf dem persönlichen iPhone installiert. Automatisches Öffnen war wegen des gesperrten iPhones nicht möglich. Live-Supabase-Anmeldung und echte StoreKit-Zahlung wurden bewusst nicht ausgelöst.

## Gesamtprüfung des persönlichen Teststands · 2026-09-10

- 16 Core-Tests und sämtliche 9 UI-Tests im gemeinsamen abschließenden Lauf erfolgreich. Signierter Release-Build inklusive Widget erfolgreich; fünf Plist-/Entitlement-/Privacy-Dateien syntaktisch geprüft.
- Widget-Fehler korrigiert: Ein laufender Termin darf den nächsten zukünftigen Termin nicht verdecken. Neuer Regressionstest umfasst unsortierte Termine, laufende/ungültige Termine und leere Listen.
- Neue UI-Abdeckung für Start ohne Konto und Einstellungen samt nicht verfügbarer Cloud-Anmeldung sowie Impressum, Datenschutz und Nutzungsbedingungen. Bereits vorhandene Kalender-, Health-Leerzustands-, Wetter-Verlaufs-, Personalisierungs- und Größen-Tests bestehen weiterhin.
- Installation der Korrektur auf dem iPhone scheiterte an zurückgesetzter Geräteverbindung; der zuvor installierte Stand bleibt bestehen.
- Umfang, Einschränkungen und Verbesserungsvorschläge: [Prüfbericht](APP_AUDIT_2026-09-10.md). Keine Aussage, dass Käufe, Live-Health/Wetter, Cloud, sämtliche Gerätevarianten oder Rechtstexte vollständig freigegeben sind.

## Ruhigeres Dashboard und Bearbeitungsmodus · 2026-09-10

- Stift oben aktiviert Bearbeiten, Haken beendet es. Diagonaler, transparenter Eckgriff nur beim Bearbeiten; keine dauerhaft sichtbare Griff-Schaltfläche und kein zusätzlicher Platz darunter. Navigation während des Bearbeitens gesperrt, damit Ziehen keine Detailseite öffnet.
- Dashboard-Wetterlogo auf 76 × 18 Punkte reduziert und innerhalb der Karte unten links platziert, ebenso in der Live-Vorschau. Quellenlink behält ein 44-Punkt-Tippziel. Wetterinhalte halten den Bereich frei; nebeneinanderliegende halbe Karten erhalten dieselbe Zeilenhöhe.
- Drei UI-Tests erfolgreich: Griff-Sichtbarkeit samt Beenden/Neustart und Ziehen, gleiche Höhen benachbarter halber Karten, Wetterdetail-/Verlauf-Navigation. Signierter Build erfolgreich, auf dem persönlichen iPhone installiert und geöffnet. Tatsächliche WeatherKit-Attribution mit Live-Wetter sowie umfassende Accessibility-Prüfung nicht erneut im Simulator verifiziert.

## Ziehgriff, Kalender-Fokus und Wetterhinweis · 2026-09-10

- Eigener 44-Punkt-Ziehbereich unten rechts: nach links auf halbe, nach rechts auf volle Breite; Speicherung beim Loslassen, VoiceOver-Verstellaktion und bisherige Breitenwahl bleiben verfügbar. Keine freie Pixelgrößen- oder Höhenänderung per Geste.
- Kalender-Fokus ist eine breite kompakte Zusammenfassung mit Datum und nächstem heutigen Termin; Überblick bleibt Tagesauswahl mit Zeitachse. Fokus wird gespeichert und in der Live-Vorschau gleich dargestellt.
- Apple-Wetterlogo bleibt sichtbar und öffnet selbst den vorgeschriebenen Quellenlink; zusätzliche sichtbare Beschriftung entfällt. Grundlage: https://developer.apple.com/weatherkit/ (Apple Weather and third-party attribution).
- 15 Core-Tests erfolgreich. Zwei neue UI-Tests erfolgreich: Ziehen in beide Richtungen mit Neustart sowie Fokus/Überblick-Unterscheidung. Screenshots geprüft; keine echten Kalender-/Gesundheitsdaten im Simulator. Vollständige VoiceOver- und Wetter-Liveprüfung nicht Teil dieses Durchlaufs.
- Signierter Gerätebuild erfolgreich und auf dem verbundenen persönlichen iPhone installiert und geöffnet.

## Widgetartige Karten und halbe Breite · 2026-09-10

- Kartenbreite unabhängig von Höhe/Pro-Größe einstellbar: Ganz oder Halb. Bestehende und unbekannte Breitenwerte laden als Ganz; die Breite bleibt auch kostenlos erhalten. Benachbarte halbe Karten teilen eine Zeile, ohne die Reihenfolge zu ändern; eine einzelne halbe Karte bleibt halb breit. Bei Accessibility-Schriftgrößen wird einspaltig dargestellt.
- Vorlagen Kompakt, Fokus und Überblick setzen Breite und passende Darstellung; Farbe, Hintergrund und persönliche Ziele bleiben erhalten. Eigene schmale Ansichten für alle sechs Datentypen, keine eingebetteten Widgets anderer Apps. Apple-Wetter-Attribution bleibt auch bei halben Wetterkarten sichtbar.
- 15 Core-Tests erfolgreich, einschließlich Breitenmigration, Codable-Roundtrip und Erhalt im kostenlosen Layout. Neuer UI-Test bestätigt Breitenwahl über App-Neustarts, zwei Karten auf gleicher Höhe mit getrennten X-Positionen und Rückstellung auf volle Breite. Screenshot visuell geprüft. Signierter iPhone-Build erfolgreich.
- Kalender-, Health-, Wetter- und Breitentest bestehen im gemeinsamen Lauf. Der Personalisierungstest musste wegen der weiter unten liegenden Farbauswahl zuerst scrollen und besteht anschließend im separaten Wiederholungslauf ebenfalls. Damit wurden alle fünf Bedienungsabläufe erfolgreich geprüft.
- Echte Daten in jeder kompakten Variante sowie umfassende VoiceOver-/Dynamic-Type-Prüfungen stehen noch aus; fehlende Messwerte werden weiterhin nicht erfunden.
- Installation dieses Standes auf dem persönlichen iPhone nicht erfolgt: CoreDevice konnte am 10.09. keine Verbindung zum gekoppelten Gerät herstellen (Fehler 4000, Verbindung zurückgesetzt). Vorherige Installationsbestätigungen gelten für ältere Stände.

## Stundenplan für Tag und Heute · 2026-09-09

- Kalenderdetails: Tag zeigt ausschließlich das Datum und einen vertikal scrollbaren Stundenplan; kein Wochen-/Monatsraster. Woche behält sieben auswählbare Tage. Heute zeigt für den ausgewählten Tag eine kompakte Zeitachse statt der bisherigen Terminliste.
- Termine sind nach Beginn und Dauer platziert. Überlappende Blöcke werden in Spalten aufgeteilt; kurze Termine erhalten eine Mindesthöhe. Ganztägige Termine stehen separat, mehrtägige Zeitblöcke werden an Tagesgrenzen gekürzt. Antippen öffnet die vollständigen Terminangaben. Eine minutenweise aktualisierte rote Linie markiert die aktuelle Uhrzeit.
- 14 Core-Tests erfolgreich, einschließlich Überlappungsspalten, Wiederverwendung freier Spalten, Tagesgrenzen und Ausschluss ganztägiger Einträge aus dem Stundenraster. Vorhandene DST-Tests bestätigen 23-/25-Stunden-Tage. Simulator-Test prüft, dass beim Umschalten auf Tag eine Zeitachse und kein Wochen-/Monatsraster erscheint; erste Tagesdarstellung visuell geprüft.
- Die Screenshots des isolierten Simulators enthalten keine echten Kalendertermine. Das Verhalten mit persönlichen Terminen und sehr großer Schrift bleibt auf dem Gerät zu prüfen.

## Tagesauswahl und Kalenderwoche 2026-09-09

- Heute-Kalender zeigt nur Termine des ausgewählten Tages, standardmäßig heute. Die sieben Tagesbuttons wechseln die Liste ohne Navigation; der Kartenkopf öffnet weiterhin die Details. Lokale Termine werden auch dann berücksichtigt, wenn sie heute bereits beendet sind; mehrtägige Termine erscheinen an jedem betroffenen Tag.
- Wochenansicht in den Kalenderdetails verwendet genau sieben Tage mit der lokalen Kalenderwoche, einschließlich Wochen über Monatsgrenzen. Tagesansicht verwendet denselben Wochenstreifen zur Tagesauswahl, Monatsansicht behält das Monatsraster.
- Simulator-Bedienungstest erfolgreich: Tageswechsel aktualisiert die Beschriftung ohne Detailnavigation, Kalenderkopf öffnet Details, Wochenraster enthält genau sieben Tagesbuttons, Rückwechsel zu Monat und Dashboard funktioniert. Signierter iPhone-Build erfolgreich. Ein zunächst zu kleiner Trefferbereich am Kartenkopf wurde auf mindestens 44 Punkte Höhe mit vollständiger rechteckiger Tippfläche korrigiert.
- Apples fertiger Schlafscore ist in der öffentlichen HealthKit-Datentyp-Dokumentation und den installierten SDK-Headern nicht auffindbar. Kein proprietärer Score oder eigener Qualitätswert wird erfunden; Schlafzielring vorerst unverändert.
- Wetter-Nachtrag: Nach Aktivierung des zusätzlichen WeatherKit-App-Service durch den Betreiber war der echte Abruf auf dem persönlichen iPhone erfolgreich: `success forecast + attribution`. Der darunter dokumentierte Authentifizierungsfehler beschreibt den Zustand davor.

## Wetterdiagnose 2026-09-09

- Auf dem persönlichen iPhone reproduziert: `forecast · WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors (2)`. Der native WeatherKit-Abruf scheitert bei der Authentifizierung; erfolgreiche echte Wetterdaten sind weiterhin nicht bestätigt. Die zusätzliche App-Service-Freischaltung im Developer-Portal ist noch ungeprüft. Aus dem Fehlercode allein lässt sich keine eindeutig fehlende Portal-Einstellung ableiten.
- Signiertes App-Binary und eingebettetes Provisioning-Profil enthalten beide die WeatherKit-Berechtigung. Signierter Diagnosebuild in einem temporären Ordner erfolgreich, auf dem iPhone installiert und gestartet. Build im Documents-Ordner scheiterte zuvor an Finder-Metadaten, nicht an Swift-Code.
- Abruf gehört jetzt dem gemeinsamen Wettermodell statt der Lebensdauer einer SwiftUI-Karte. Zeitgrenze von 30 Sekunden, erzwungener Neuversuch und gegen veraltete Antworten abgesicherter Ortswechsel. Fehlerstufe und Domain/Code werden sichtbar; keine Token, Koordinaten oder beliebigen Fehler-Payloads in der Diagnoseausgabe.
- Wetter-Bedienungstest im Simulator erfolgreich. Er prüft Navigation, nicht die erfolgreiche Apple-Authentifizierung. Der echte iPhone-Abruf mit explizitem `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG` und Startargument `--weather-diagnostic` bestätigt den obigen Fehler. Das Startargument ist nur im Diagnosebuild aktiv und verändert keine Kartenauswahl.

## Kartenkorrektur 2026-09-09

- Kalender ohne Statistikdiagramme: Monatsraster, Tagesauswahl und Terminliste mit stabilen Farben je Kalenderquelle. Farben stellen keine aktive Partnerverknüpfung dar.
- Puls auf „Heute“ verwendet stündliche Mittelwerte des aktuellen Tages; weitere Zeiträume bleiben in den Details verfügbar.
- Schlaf verwendet standardmäßig einen Schlafzielring, keinen erfundenen Qualitätswert. Alte Balken-/Linieneinstellungen werden beim Laden umgestellt; Farbe, Größe und Ziel bleiben erhalten. Auch große Schlafkarten zeigen kein zusätzliches Wochendiagramm.
- Verifiziert: zwölf Core-Tests und vier Bedienungstests auf einem frischen Simulator erfolgreich; Monatsraster im Screenshot visuell geprüft. Ein vorheriger paralleler Testlauf auf demselben Simulator war durch gegenseitige App-Neustarts gestört; der abschließende isolierte Lauf besteht vollständig. Reale Puls-/Schlafdaten und Installation dieses Standes auf dem persönlichen iPhone bleiben ungeprüft.

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
