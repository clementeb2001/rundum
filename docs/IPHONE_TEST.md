# Rundum auf dem eigenen iPhone testen

## Was jetzt ohne Backend funktioniert

Dashboard, sechs Karten inklusive Wetter, lokale Apple-Health-Daten, auf dem iPhone eingerichtete Kalender, Kartengrößen, Homescreen-Widget sowie die Rechtstext-Testfassungen. Eine Internetverbindung und eine korrekt aktivierte/signierte WeatherKit-App sind für reale Wetterdaten erforderlich. Es werden keine Wetterwerte erfunden, wenn Apple die Anfrage ablehnt.

Anmeldung, geräteübergreifender Sync und gemeinsame Rundum-Kalender brauchen weiterhin ein Supabase-Projekt. Für persönliche lokale Tests ist das nicht nötig. AGB/Datenschutz/Impressum sind ausdrücklich Entwürfe für diesen Test, keine fertigen Veröffentlichungsdokumente.

## Einmalige Einrichtung

1. iPhone per Kabel mit dem Mac verbinden, entsperren und dem Mac vertrauen. In Xcode muss das Gerät als Run Destination sichtbar werden. Falls angefordert: iPhone → Einstellungen → Datenschutz & Sicherheit → Entwicklermodus aktivieren und die Bestätigung nach dem Neustart selbst durchführen.
2. **Rundum.xcodeproj** öffnen, nicht `Package.swift`. Unter Xcode → Settings → Accounts mit dem Apple-Developer-Konto anmelden.
3. Im Projekt unter **Signing & Capabilities** für **Rundum** und **RundumWidget** dasselbe eigene Entwicklungsteam und Automatic Signing wählen. Die Bundle-IDs müssen zur eigenen Registrierung passen. Beide Targets brauchen dieselbe eigene App Group; die App zusätzlich HealthKit und WeatherKit.
4. Alternativ bzw. reproduzierbar: `Config/Local.xcconfig.example` nach `Config/Local.xcconfig` kopieren und `DEVELOPMENT_TEAM`, `APP_BUNDLE_ID`, `WIDGET_BUNDLE_ID` und `APP_GROUP_ID` eintragen. Die Widget-Bundle-ID muss die App-ID als Präfix haben, zum Beispiel `com.deinname.rundum.widget` für `com.deinname.rundum`. Keine fremden IDs übernehmen. Die lokale Datei wird nicht nach Git übertragen.
5. Im Apple-Developer-Portal bei der passenden App-ID **WeatherKit sowohl unter Capabilities als auch unter App Services** aktivieren. Anschließend Xcode die Provisioning-Profile aktualisieren lassen. Die native Swift-API benötigt keinen im Quellcode gespeicherten privaten API-Schlüssel.
6. Schema **Rundum** plus eigenes iPhone auswählen und ⌘R drücken. Dieses Schema nutzt lokale StoreKit-Testkäufe: Pro kann kostenlos ausprobiert werden. Für Tests ohne lokale StoreKit-Simulation gibt es **Rundum Device**; echte App-Store-Produkte müssen dafür separat eingerichtet sein. Das Device-Schema ist keine automatische TestFlight-Veröffentlichung.

Die persönlichen Betreiberangaben dürfen beim privaten Test leer bleiben. Vor öffentlicher Verteilung werden `OPERATOR_NAME`, `OPERATOR_ADDRESS` und `SUPPORT_EMAIL` sowie tatsächliche Hosting-/Verarbeitungsangaben und die Rechtstexte vervollständigt. Private Angaben nicht versehentlich in das öffentliche Repository committen.

## Wetter prüfen

- Unter „Dashboard anpassen“ die Karte **Wetter** einschalten. Kostenlos sind insgesamt zwei aktive Karten möglich; mit lokalem Pro-Testabo alle sechs.
- Luxemburg ist der voreingestellte Ort. Die Ortsauswahl enthält weitere Orte der Großregion und eine Suche.
- Kleines Widget: aktueller Wert und Tagesminimum/-maximum. Mittel: zusätzlich Wind, gefühlte Temperatur und sechs Stunden Vorschau. Groß: zusätzlich fünf Tage.
- Standortzugriff ist optional und erfolgt nur nach Betätigung. Rundum rundet Gerätekoordinaten auf zwei Dezimalstellen. Keine Hintergrund-Ortung. Bei Ablehnung kann eine Stadt ausgewählt werden.
- Ohne Verbindung oder gültige WeatherKit-Berechtigung erscheint ein Fehlerzustand mit erneutem Laden; vorhandene Daten bleiben mit Abrufdatum gekennzeichnet.
- Apple-Weather-Marke und Datenquellen stehen an der Wetterkarte. Reale Daten und Attribution konnten ohne signierte WeatherKit-App noch nicht Ende-zu-Ende bestätigt werden.

## Prüfen vor Veröffentlichung

Eigene Geräte und reale HealthKit-Daten; WeatherKit-Daten und Branding in Hell/Dunkel; Widerruf von Kalender-/Standortrechten; große Schrift/VoiceOver; Testkäufe/Kündigung; Backend-Rechteprüfung mit zwei Nutzern; Konto-/Datenlöschung und Support; tatsächliche Rechtstexte und Betreiberangaben. Pro-Verlaufsanalysen und unbegrenzte serverseitig geprüfte Familienkalender sind weiterhin nicht fertig und dürfen nicht als verfügbar beworben werden.

Quellen: [Apple WeatherKit aktivieren](https://developer.apple.com/help/account/services/weatherkit), [App auf einem Gerät ausführen](https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html), [Entwicklermodus](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device), [CNPD: Recht auf Information](https://cnpd.public.lu/fr/particuliers/vos-droits/droit-a-information.html).
