# Rundum

**Aktueller persönlicher Teststand:** Wetter mit Apple WeatherKit ist als sechste Dashboard-Karte integriert. Ortsauswahl, optionale einmalige Standortabfrage, Stunden-/Tagesvorschau und Apple-Attribution sind enthalten. Impressum, Datenschutz und Nutzungsbedingungen sind in den Einstellungen als **Testfassungen** erreichbar; Betreiberangaben können für den privaten Test noch fehlen. Siehe **[iPhone-Testanleitung](docs/IPHONE_TEST.md)**. Cloud-Anmeldung ist per E-Mail/Passwort und nativ mit Apple vorbereitet; ein Supabase-Projekt muss pro Installation einmalig mit Projekt-URL und öffentlichem Schlüssel verbunden werden.

Native SwiftUI-App für iOS 16+: persönlicher Tagesüberblick, modulare Dashboard-Karten, lokale Apple-Health-Daten und gemeinsame Kalender. Deutsch, Französisch und Englisch. Keine Drittanbieter-SDKs erforderlich.

## Starten

1. `Rundum.xcodeproj` in Xcode öffnen.
2. Scheme **Rundum**, iPhone-Simulator auswählen und ▶ drücken. Das lokale Dashboard funktioniert ohne Cloud-Konfiguration. HealthKit benötigt für realistische Daten ein iPhone mit Apple Health.
3. Für ein echtes iPhone ein eigenes Signing-Team sowie eindeutige Bundle-IDs für App und Widget einstellen. HealthKit für die App und dieselbe App Group für beide Targets aktivieren.

Das Xcode-Projekt und das App-Icon sind bereits enthalten. Nach Änderungen an der Dateistruktur kann es ohne zusätzliche Pakete mit `python3 scripts/generate_project.py` neu erzeugt werden. Änderungen an Target-Einstellungen dann auch im Generator übernehmen. Das originale App-Icon wird mit `swift scripts/generate_icon.swift` erzeugt.

## Funktionsumfang

**Widgetartige Anordnung:** Unter „Dashboard anpassen“ eine Karte öffnen und eine Vorlage wählen oder unter „Breite“ auf „Halb“ stellen. Zwei aufeinanderfolgende halbe Karten erscheinen nebeneinander. Die Reihenfolge lässt sich weiter ändern. Farben und Hintergründe bleiben individuell; Live-Vorschau zeigt die schmale Variante. Dies sind Rundum-eigene Karten mit angebundenen Daten, keine übernommene Widget-Oberfläche einer fremden App. Breitenwahl ist auch ohne Pro verfügbar; das bestehende Limit aktiver Karten und Pro-Höhen bleiben unverändert.

- Geführte Kartenauswahl ohne Konto, danach anpassbares Dashboard mit sechs Karten: Kalender, Schritte, Schlaf, Puls, Workouts und Wetter.
- Karten aktivieren/deaktivieren; Drag & Drop im Dashboard und sortierbare Liste mit System-Bedienelementen. Freemium-Limit von zwei sichtbaren Karten; zusätzliche Karten und drei Größen bei verifiziertem StoreKit-Abo.
- Jede Karte öffnet eine eigene Detailseite. Farben (Automatisch plus acht Farbtöne), drei Hintergründe und je nach Datentyp Werte, Balken, Linien, Zielringe oder Agenda sind pro Karte einstellbar und bleiben nach einem Neustart erhalten. Persönliche Ziele sind Anzeigepräferenzen, keine medizinischen Empfehlungen.
- Gesundheits- und Kalenderdetails bieten Tag, Woche, Monat und Jahr. Fehlende Gesundheitswerte bleiben fehlend; überlappende Schlafintervalle werden zusammengeführt. Herzfrequenz-Mittelwerte beziehen sich auf die dargestellten Intervalle, Schlafmittelwerte auf aufgezeichnete Nächte. Die Gesundheitsverläufe bleiben ausschließlich im Arbeitsspeicher auf dem Gerät.
- Wetterdetails mit Stunden-/Tagesvorhersage und Messgrößen; ab iOS 18 zusätzlich historische Tagesminimum/-maximum-Temperaturen von WeatherKit ab August 2021. Verlauf benötigt eine gültige WeatherKit-Freischaltung; Datumsgrenzen verwenden die iPhone-Zeitzone.
- EventKit liest ausgewählte iOS-Kalender für die nächsten sieben Tage. Google-Kalender müssen zuvor in iOS eingebunden sein. Private Termine verlassen das Gerät nicht, außer dem ausdrücklich aktivierten lokalen Widget-Snapshot.
- HealthKit liest Schritte, letzte Nacht, heutige Herzfrequenz und Trainingsminuten. Überlappende Schlafquellen werden zusammengeführt. Keine Health-Daten im Backend, in Dateien oder im Homescreen-Widget. Keine Datenfreigabe an Familienmitglieder.
- Lokale, pro Konto getrennte Dashboard-Konfiguration; Cloud-Sync bei Änderungen, App-Aktivierung und manuellem Aktualisieren. Einfaches Last-write-wins für vollständige Layouts; Offline-Layouts bleiben erhalten.
- Supabase-E-Mail/Passwort-Anmeldung sowie native Apple-Anmeldung mit sicherem Nonce-/ID-Token-Austausch, Keychain-Sitzung, Token-Erneuerung, Abmeldung und Kontolöschung.
- Eigenständige gemeinsame Rundum-Kalender: erstellen, per einmaligem Code beitreten, Termine hinzufügen/bearbeiten/löschen, Kalender verlassen/löschen. Einladungen laufen nach sieben Tagen ab. RLS trennt Konten und Mitgliedschaften; nur Ersteller oder Kalendereigentümer dürfen Termine ändern/löschen.
- WidgetKit-Erweiterung für kleine/mittlere Homescreen-Widgets. Nächster privater Termin nur nach separater Zustimmung in Einstellungen; veraltete Termine werden ausgeblendet.
- Semantische Schriftgrößen, Dynamic Type, Systemkomponenten und VoiceOver-Beschriftungen. Für tatsächliche Barrierefreiheit steht die Geräteprüfung noch aus.

## Cloud einrichten

1. Ein eigenes Supabase-Projekt anlegen (für die gewünschte EU-Datenhaltung eine passende Region wählen).
2. `Backend/001_initial.sql` einmal in einer neuen Datenbank ausführen. Sie richtet Tabellen, RLS, Berechtigungen und geschützte RPCs ein. Bei bestehenden Daten zuerst eine eigene Migration planen.
3. E-Mail/Passwort-Auth, E-Mail-Bestätigung, Versand und Rate Limits im Projekt konfigurieren. Der Anmeldevorgang verwendet keine frei erfundenen Zugangsdaten.
4. Projekt-URL und **öffentlichen anon/publishable key** entweder in der App unter **Gemeinsam → Anmeldung einrichten** sicher hinterlegen oder für feste Entwicklungsbuilds `Config/Local.xcconfig.example` nach `Config/Local.xcconfig` kopieren. Niemals `service_role` verwenden; die App lehnt solche Schlüssel ab. `Local.xcconfig` ist von Git ausgeschlossen.
5. Mit zwei Testkonten Anmeldung, Einladung, RLS, Kontowechsel, Offline-Sync und Löschung prüfen. Das bereitgestellte `Backend/access_checks.sql` enthält zusätzliche transaktionale SQL-Prüfungen für eine isolierte Testdatenbank.

Für **Mit Apple anmelden** zusätzlich die Capability für die App-ID `app.rundum.ios` im Apple Developer Portal aktivieren und im Supabase-Apple-Provider dieselbe Bundle-ID als Client ID eintragen. Der native Ablauf benötigt keine Services ID und keinen regelmäßig zu erneuernden OAuth-Secret-Key.

Die Cloud ist im ausgelieferten Projekt noch nicht mit einem echten Dienst verbunden. Ohne diese Konfiguration erklärt die App den Zustand und funktioniert lokal weiter. Nach der einmaligen Einrichtung sind E-Mail-Anmeldung und Kontoerstellung direkt in Rundum verfügbar; für Familienkalender muss zusätzlich Schritt 2 ausgeführt sein.

## Abonnements

### Pro kostenlos im Simulator testen

Öffne **Rundum.xcodeproj**, nicht `Package.swift`. Wähle das Schema **Rundum** und einen iPhone-Simulator und starte mit **⌘R** aus Xcode. Im Run-Schema ist `Config/Rundum.storekit` bereits als lokale StoreKit-Konfiguration hinterlegt. Sie enthält `app.rundum.pro.monthly` für 3,99 EUR pro Monat, Storefront Luxemburg, ohne App-Store-Connect-Anbindung.

Öffne in der App **Einstellungen → Rundum Pro** und bestätige den lokalen Testkauf. Es wird kein echtes Geld abgebucht. Danach sind alle fünf Karten und zusätzliche Größen verfügbar. Testtransaktionen kannst du in Xcode unter **Debug → StoreKit → Manage Transactions** verwalten. Beim normalen Start per `simctl launch` wird die Xcode-Schemakonfiguration nicht automatisch aktiviert; für diese Testkäufe daher aus Xcode starten. Die Testdatei ist keine App-Ressource und verändert das Verhalten einer veröffentlichten App nicht.

StoreKit 2 ist eingebaut: Produkt laden, Kauf, verifizierte Entitlements, Wiederherstellen und Transaktionsupdates. Produkt-ID: `app.rundum.pro.monthly`, überschreibbar in `Local.xcconfig`. Produkt, monatliche Laufzeit, Preis und Verfügbarkeit müssen in App Store Connect eingerichtet werden. Die App zeigt den tatsächlichen StoreKit-Preis an; ohne Produkt ist kein Kauf möglich.

**Noch nicht fertig:** serverseitige App-Store-Transaktionsverifikation für unbegrenzte gemeinsame Kalender. Deshalb begrenzt die Datenbank derzeit alle Konten auf einen selbst erstellten gemeinsamen Kalender; das Kaufangebot verspricht keine unbegrenzten Kalender. Einem bestehenden Kalender kann man zusätzlich per Einladung beitreten. Lokale Gesundheitsverläufe sind inzwischen für aktive Karten verfügbar, ohne zusätzliche Pro-Sperre; weiterführende medizinische Auswertungen werden nicht angeboten.

## Architektur

| Bereich | Verantwortung |
|---|---|
| `Core/` | Plattformunabhängige Kartenkonfiguration, stabile IDs, Kalendermodelle, Schlaf-Intervallberechnung |
| `App/CardRegistry.swift` | Registrierung von Karten mit eigener SwiftUI-Renderfunktion |
| `App/DeviceServices.swift` | EventKit und HealthKit, Zugriffsanfragen und lokale Abfragen |
| `App/CloudService.swift` | Supabase REST/Auth, Keychain, gemeinsame Kalender |
| `App/AppState.swift` | Persistenz, Sync, verifizierte StoreKit-Entitlements, Widget-Snapshot |
| `App/*View*.swift` | Onboarding, Dashboard, Bibliothek, Familie, Konto und Einstellungen |
| `Widget/` | Separater WidgetKit-Prozess ohne HealthKit-Zugriff |
| `Backend/` | SQL-Schema, Datenzugriffsregeln, scoped RPCs, Zugriffstests |

Eine neue Karte erhält eine stabile `CardKind(rawValue:)`-ID, eine View und einen Eintrag in `CardRegistry.plugins`. Das Dashboard rendert über die Registry. Persistenz und Sync müssen nicht angepasst werden; unbekannte Karten-IDs bleiben bei älteren App-Versionen erhalten. Titel/Icon einer neuen Karte können in `Copy.card`/`CardKind.symbol` ergänzt werden. Neue Datenquellen erhalten einen eigenen Dienst; keine Netzwerkabfragen in Views.

## Prüfung

```sh
swift test
xcodebuild -project Rundum.xcodeproj -scheme Rundum \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

Bei eingeschränkten Cache-Rechten:

```sh
CLANG_MODULE_CACHE_PATH="$PWD/build/clang-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/build/swift-module-cache" \
swift test --scratch-path build/core-tests --cache-path build/swift-cache --disable-sandbox
```

Siehe `docs/VALIDATION.md` für tatsächlich durchgeführte Prüfungen und `docs/ROADMAP.md` für den verbleibenden Weg bis zur Veröffentlichung. Der Quellcode ist eine erste kompilierbare Implementierung, keine bereits freigegebene App-Store-Version.

Der vollständige Simulator-Build inklusive App-Icon und Widget sowie Bedienungstests wurden inzwischen erfolgreich ausgeführt; aktuelle Prüfergebnisse und verbleibende Geräteprüfungen stehen im Prüfprotokoll.
