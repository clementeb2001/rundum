import XCTest

/// Runs on an isolated simulator. No synthetic health data or production entitlements are injected.
final class CardFlowTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-onboarded", "YES", "-AppleLanguages", "(de)", "-AppleLocale", "de_LU"]
        app.launch()
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testSettingsLegalAndUnavailableCloud() {
        app.tabBars.buttons["Einstellungen"].tap()
        app.buttons["Anmelden für Sync & Familie"].tap()
        XCTAssertTrue(app.staticTexts["Die Cloud ist für diese App-Version noch nicht eingerichtet. Du kannst das Dashboard und deine lokalen Daten bereits nutzen."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.secureTextFields.firstMatch.exists)
        app.buttons["cloud-setup"].tap()
        XCTAssertTrue(app.textFields["cloud-project-url"].waitForExistence(timeout: 5))
        app.textFields["cloud-project-url"].tap(); app.textFields["cloud-project-url"].typeText("https://example.supabase.co")
        app.secureTextFields["cloud-public-key"].tap(); app.secureTextFields["cloud-public-key"].typeText("service_role_secret")
        app.buttons["save-cloud-configuration"].tap()
        XCTAssertTrue(app.staticTexts["Nur einen öffentlichen publishable- oder anon-Schlüssel verwenden. Niemals service_role."].waitForExistence(timeout: 5))
        app.navigationBars["Anmeldung einrichten"].buttons["Abbrechen"].tap()
        app.navigationBars["Willkommen"].buttons["Abbrechen"].tap()
        for title in ["Impressum", "Datenschutzerklärung", "Nutzungsbedingungen"] {
            let link = app.buttons[title]
            for _ in 0..<8 where !link.isHittable { app.swipeUp() }
            XCTAssertTrue(link.waitForExistence(timeout: 5)); link.tap()
            XCTAssertTrue(app.staticTexts["Testfassung · Stand 08.09.2026"].waitForExistence(timeout: 5))
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        screenshot("settings-legal-test-drafts")
    }
    func testOfflineWeatherAndLargeTextRemainUsable() {
        app.terminate()
        app.launchArguments = ["-onboarded", "YES", "-AppleLanguages", "(de)", "-AppleLocale", "de_LU", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge", "--weather-offline-test"]
        app.launch()
        app.buttons["dashboard-customize"].tap()
        setCard("calendar", enabled: false); setCard("weather", enabled: true)
        app.buttons["Fertig"].tap()
        let card = app.buttons["dashboard-card-weather"]
        for _ in 0..<6 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Keine Verbindung · später erneut versuchen"].exists)
        XCTAssertTrue(app.buttons["dashboard-edit"].exists)
        screenshot("offline-weather-accessibility-text")
        app.buttons["dashboard-customize"].tap(); setCard("weather", enabled: false); setCard("calendar", enabled: true)
    }
    func testProScreenNeverClaimsUnverifiedPurchase() {
        app.tabBars.buttons["Einstellungen"].tap()
        let pro = app.buttons["Rundum Pro"]
        for _ in 0..<6 where !pro.isHittable { app.swipeUp() }
        XCTAssertTrue(pro.waitForExistence(timeout: 5)); pro.tap()
        XCTAssertTrue(app.buttons["Käufe wiederherstellen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Rundum Pro ist aktiv."].exists)
        XCTAssertTrue(app.staticTexts["Der Kauf ist momentan nicht verfügbar."].exists || app.buttons.matching(NSPredicate(format: "label CONTAINS 'Monat'")).firstMatch.exists)
        screenshot("pro-unverified-state")
    }
    func testOnboardingCanStartWithoutAccount() {
        app.terminate()
        app.launchArguments = ["-onboarded", "NO", "-AppleLanguages", "(de)", "-AppleLocale", "de_LU"]
        app.launch()
        let start = app.buttons["Mein Rundum starten"]
        for _ in 0..<6 where !start.isHittable { app.swipeUp() }
        XCTAssertTrue(start.waitForExistence(timeout: 5)); start.tap()
        XCTAssertTrue(app.buttons["dashboard-customize"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.secureTextFields.firstMatch.exists)
        screenshot("onboarding-local-dashboard")
    }
    private func setCard(_ kind: String, enabled: Bool) {
        let toggle = app.switches["enable-card-" + kind]
        for _ in 0..<5 where !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let expected = enabled ? "1" : "0"
        if toggle.value as? String != expected {
            // SwiftUI exposes the complete row as a switch; hit the trailing control.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        expectation(for: NSPredicate(format: "value == %@", expected), evaluatedWith: toggle)
        waitForExpectations(timeout: 5)
    }
    func testCalendarDetailPeriodsAndReturn() {
        let dayLabel = app.staticTexts["calendar-selected-day"]
        XCTAssertTrue(dayLabel.waitForExistence(timeout: 10))
        let todayLabel = dayLabel.label
        app.buttons["calendar-day-1"].tap()
        XCTAssertNotEqual(dayLabel.label, todayLabel)
        XCTAssertFalse(app.segmentedControls["history-period"].exists)
        app.buttons["calendar-day-0"].tap()
        let card = app.buttons["dashboard-card-calendar"]
        XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        let periods = app.segmentedControls["history-period"]
        XCTAssertTrue(periods.waitForExistence(timeout: 5))
        periods.buttons["Monat"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendar-month-grid"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls.buttons["Balken"].exists)
        periods.buttons["Woche"].tap()
        let week = app.descendants(matching: .any)["calendar-week-grid"].firstMatch
        XCTAssertTrue(week.waitForExistence(timeout: 5))
        XCTAssertEqual(week.buttons.count, 7)
        periods.buttons["Tag"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendar-day-timeline"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["calendar-week-grid"].firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any)["calendar-month-grid"].firstMatch.exists)
        screenshot("calendar-day-hours")
        periods.buttons["Monat"].tap()
        app.buttons["history-previous"].tap()
        screenshot("calendar-history")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["dashboard-customize"].waitForExistence(timeout: 5))
    }
    func testPersonalizationPersistsAcrossLaunch() {
        app.buttons["dashboard-customize"].tap()
        let steps = app.buttons["customize-card-steps"]
        XCTAssertTrue(steps.waitForExistence(timeout: 5)); steps.tap()
        let pink = app.buttons["card-color-pink"]
        for _ in 0..<4 where !pink.isHittable { app.swipeUp() }
        XCTAssertTrue(pink.waitForExistence(timeout: 5)); pink.tap()
        screenshot("card-personalization")
        app.terminate(); app.launch()
        app.buttons["dashboard-customize"].tap()
        let row = app.buttons["customize-card-steps"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Pink")); row.tap()
        let restored = app.buttons["card-color-pink"]
        for _ in 0..<7 where !restored.isHittable { app.swipeUp() }
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        XCTAssertTrue(restored.isSelected)
        screenshot("card-personalization-restored")
    }
    func testCornerDragResizesAndPersists() {
        let handle = app.descendants(matching: .any)["resize-card-steps"].firstMatch
        XCTAssertFalse(handle.exists)
        app.buttons["dashboard-edit"].tap()
        for _ in 0..<5 where !handle.isHittable { app.swipeUp() }
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -90, dy: 0)))
        app.terminate(); app.launch()
        let card = app.buttons["dashboard-card-steps"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertLessThan(card.frame.width, app.frame.width * 0.6)
        XCTAssertFalse(handle.exists)
        screenshot("corner-resize-half")
        app.buttons["dashboard-edit"].tap()
        for _ in 0..<5 where !handle.isHittable { app.swipeUp() }
        let half = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        half.press(forDuration: 0.05, thenDragTo: half.withOffset(CGVector(dx: 90, dy: 0)))
        app.terminate(); app.launch()
        XCTAssertGreaterThan(card.frame.width, app.frame.width * 0.7)
        app.buttons["dashboard-edit"].tap()
        XCTAssertTrue(handle.exists)
        app.buttons["dashboard-edit"].tap()
        XCTAssertFalse(handle.exists)
    }
    func testCalendarFocusDiffersFromOverview() {
        func template(_ name: String) {
            app.buttons["dashboard-customize"].tap()
            app.buttons["customize-card-calendar"].tap()
            let button = app.buttons[name]
            for _ in 0..<5 where !button.isHittable { app.swipeUp() }
            XCTAssertTrue(button.waitForExistence(timeout: 5)); button.tap()
            app.terminate(); app.launch()
        }
        template("Fokus")
        let summary = app.descendants(matching: .any)["calendar-focus-summary"].firstMatch
        for _ in 0..<5 where !summary.isHittable { app.swipeUp() }
        XCTAssertTrue(summary.exists)
        XCTAssertFalse(app.buttons["calendar-day-0"].exists)
        screenshot("calendar-wide-focus")
        app.terminate(); app.launch()
        template("Überblick")
        XCTAssertTrue(app.buttons["calendar-day-0"].waitForExistence(timeout: 5))
    }
    func testWidgetWidthsPlaceTwoCardsSideBySide() {
        func width(_ kind: String, _ value: String) {
            app.buttons["dashboard-customize"].tap()
            let row = app.buttons["customize-card-" + kind]
            XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
            let picker = app.segmentedControls["card-width"]
            for _ in 0..<7 where !picker.isHittable { app.swipeUp() }
            XCTAssertTrue(picker.waitForExistence(timeout: 5)); picker.buttons[value].tap()
            app.terminate(); app.launch()
        }
        width("calendar", "Halb"); width("steps", "Halb")
        let first = app.buttons["dashboard-card-calendar"]
        let second = app.buttons["dashboard-card-steps"]
        XCTAssertTrue(first.waitForExistence(timeout: 5)); XCTAssertTrue(second.exists)
        XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 3)
        XCTAssertEqual(first.frame.height, second.frame.height, accuracy: 3)
        XCTAssertGreaterThan(abs(first.frame.minX - second.frame.minX), 50)
        XCTAssertLessThan(first.frame.width, app.frame.width * 0.6)
        screenshot("two-half-width-widgets")
        width("calendar", "Ganz"); width("steps", "Ganz")
    }
    func testHealthDetailShowsPermissionsWithoutInventedValues() {
        let steps = app.buttons["dashboard-card-steps"]
        for _ in 0..<4 where !steps.isHittable { app.swipeUp() }
        XCTAssertTrue(steps.waitForExistence(timeout: 5)); steps.tap()
        XCTAssertTrue(app.segmentedControls["history-period"].waitForExistence(timeout: 5))
        app.segmentedControls["history-period"].buttons["Jahr"].tap()
        XCTAssertTrue(app.buttons["Apple Health verbinden"].exists)
        screenshot("health-history-permission-state")
    }
    func testWeatherDetailAndHistoryEmptyState() {
        app.buttons["dashboard-customize"].tap()
        setCard("calendar", enabled: false)
        setCard("weather", enabled: true)
        app.buttons["Fertig"].tap()
        let card = app.buttons["dashboard-card-weather"]
        for _ in 0..<4 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        let history = app.segmentedControls.buttons["Verlauf"]
        XCTAssertTrue(history.waitForExistence(timeout: 5)); history.tap()
        let periods = app.segmentedControls["history-period"]
        XCTAssertTrue(periods.waitForExistence(timeout: 5)); periods.buttons["Tag"].tap()
        XCTAssertTrue(app.staticTexts["Noch keine abgeschlossenen Tage in diesem Zeitraum. Wähle einen früheren Zeitraum."].waitForExistence(timeout: 10))
        screenshot("weather-history-empty-state")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["dashboard-customize"].tap()
        setCard("weather", enabled: false)
        setCard("calendar", enabled: true)
        app.buttons["Fertig"].tap()
    }
}
