# Umsetzung und nächste Meilensteine

Das Briefing wurde als fachliche Produktspezifikation für eine native iOS-App verwendet. Keine Web-App, kein Ersatz durch eine Website. Die erste Implementierung setzt die lokalen Kernfunktionen und die Cloud-Schnittstellen um.

## Verbleibende Produktarbeit

1. **Cloud und Geräteprüfung:** Supabase bereitstellen, Migration und Zugriffstests ausführen; Auth-E-Mails und Wiederherstellung für vergessene Passwörter ergänzen; Einladungen mit zwei Geräten testen. Apple-IDs und App-Groups konfigurieren.
2. **Kalender vertiefen:** Wiederholungen, Ganztagstermine, Mitgliederverwaltung und gezielter Entzug einzelner Mitgliedschaften. Heute gibt es Erstellen/Bearbeiten/Löschen von Terminen sowie Verlassen bzw. Löschen eines ganzen Kalenders. EventKit kann keine Freigabe eines bestehenden Apple-/Google-Kalenders an beliebige Konten erzeugen; solche Freigaben erfolgen beim Kalenderanbieter. Rundum bietet daher einen getrennten gemeinsamen Kalender.
3. **Vollständiges Pro-Angebot:** serverseitig geprüfte App-Store-Abos für Kalenderlimits, Verlaufsanalysen und StoreKit-Sandbox-Tests. Kein clientseitiger `isPro`-Wert darf Datenbanklimits freischalten. Eine serverseitige Verifikation ist noch nicht implementiert.
4. **Release-Qualität:** App-Icon/Branding finalisieren, UI-Automation, VoiceOver und große Schrift auf echten Geräten, Französisch/Englisch redaktionell prüfen, iOS-16- und aktuelle iOS-Geräte testen. HealthKit mit echter Uhr und verweigerten/teilweisen Freigaben prüfen.
5. **Betrieb:** Betreiberangaben, öffentliche Datenschutzerklärung, Support, Datenexport, Auftragsverarbeitungsvertrag und tatsächliche Datenschutzprüfung; App-Store-Datenschutzangaben entsprechend dem produktiven Backend vervollständigen. Diese Implementierung ist keine Zusage einer rechtlichen Zertifizierung.

Wetter, Aufgaben, Einkaufslisten, Standorte und Finanzen sind ausdrücklich spätere Erweiterungen und werden nicht als fertige Funktionen dargestellt. Das Homescreen-Widget zeigt derzeit Kalenderinformationen, nicht alle priorisierten Kartentypen. Gesundheitsdaten werden bewusst nicht in einen Widget-Cache kopiert.

## Aufwand und Planung

Arbeitsannahme: ein erfahrener iOS-Entwickler, vorhandene Apple-/Backend-Konten, schneller Zugang zu Testpersonen. Schätzung für einen belastbaren MVP inklusive Integration und Veröffentlichung: ungefähr **45–65 Entwicklungstage**. Kalender-Sharing, Sync-Konflikte, Geräte-/Datenschutzprüfung und App-Review sind die größten Unbekannten.

- Wochen 1–3: Architektur, Onboarding, Design, lokale Datenquellen.
- Wochen 4–7: Auth, Sync, gemeinsame Kalender und Rechteprüfung.
- Wochen 8–10: WidgetKit, Abos, Mehrsprachigkeit und Barrierefreiheit.
- Wochen 11–14: Tests auf Geräten, Familien-Pilot, Fehlerkorrekturen, Veröffentlichung.

Diese 3–4 Monate setzen weitgehend verfügbare Entwicklungszeit voraus. Bei 10–15 Stunden pro Woche neben einem Vollzeitjob dauert derselbe Umfang eher 6–12 Monate oder benötigt Unterstützung und eine weitere Reduktion. Die vorliegende Implementierung verkürzt den Projektstart; sie ersetzt weder die Einrichtung externer Konten noch Pilotbetrieb und Gerätevalidierung.
