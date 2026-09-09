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
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        for _ in 0..<4 where !restored.isHittable { app.swipeUp() }
        XCTAssertTrue(restored.isSelected)
        screenshot("card-personalization-restored")
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
