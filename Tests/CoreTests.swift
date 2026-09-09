import XCTest
@testable import RundumCore
final class CoreTests: XCTestCase {
    func testCalendarAndSleepMigrateAwayFromDashboardCharts() throws {
        let calendar = try JSONDecoder().decode(DashboardCard.self, from: Data(#"{"id":"calendar","presentation":"bars","tint":"pink"}"#.utf8))
        let sleep = try JSONDecoder().decode(DashboardCard.self, from: Data(#"{"id":"sleep","presentation":"bars","goal":7.5}"#.utf8))
        XCTAssertEqual(calendar.presentation, .agenda)
        XCTAssertEqual(calendar.tint, .pink)
        XCTAssertEqual(CardKind.calendar.presentations, [.agenda])
        XCTAssertEqual(sleep.presentation, .ring)
        XCTAssertEqual(sleep.goal, 7.5)
        XCTAssertEqual(DashboardCard(id: .sleep).presentation, .ring)
    }
    func testFreeLimitAndPreservedProLayout() {
        var config = DashboardConfiguration()
        XCTAssertFalse(config.setEnabled(.sleep, enabled: true, isPro: false))
        XCTAssertTrue(config.setEnabled(.sleep, enabled: true, isPro: true))
        XCTAssertEqual(config.visibleCards(isPro: false).count, 2)
        XCTAssertEqual(config.cards.count, 3)
        XCTAssertTrue(config.setEnabled(.steps, enabled: false, isPro: false))
        XCTAssertEqual(config.cards.map(\.id), [.calendar, .sleep])
    }
    func testSleepOverlapsClippingAndGaps() {
        let d = Date(timeIntervalSince1970: 0)
        func interval(_ a: Double, _ b: Double) -> DateInterval { .init(start: d.addingTimeInterval(a * 3600), end: d.addingTimeInterval(b * 3600)) }
        XCTAssertEqual(SleepMath.hours(intervals: [interval(-2, 3), interval(2, 5), interval(6, 9)], within: interval(0, 8)), 7)
        XCTAssertEqual(SleepMath.hours(intervals: [], within: interval(0, 8)), 0)
    }
    func testConfigurationRoundTripPreservesOrderAndSizes() throws {
        let original = DashboardConfiguration(cards: [.init(id: .sleep, size: .large), .init(id: .calendar, size: .small)])
        XCTAssertEqual(try JSONDecoder().decode(DashboardConfiguration.self, from: JSONEncoder().encode(original)), original)
    }
    func testUnknownPluginIsPreservedAcrossVersions() throws {
        let config = DashboardConfiguration(cards: [.init(id: .init(rawValue: "future.weather"))])
        let restored = try JSONDecoder().decode(DashboardConfiguration.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(restored.cards.first?.id.rawValue, "future.weather")
    }
    func testLegacyCardMigrationPreservesLayout() throws {
        let json = #"{"cards":[{"id":"sleep","size":"large"},{"id":"calendar","size":"small"}],"updatedAt":0}"#
        let config = try JSONDecoder().decode(DashboardConfiguration.self, from: Data(json.utf8))
        XCTAssertEqual(config.cards.map(\.id), [.sleep, .calendar])
        XCTAssertEqual(config.cards.first?.size, .large)
        XCTAssertEqual(config.cards.first?.presentation, .ring)
        XCTAssertEqual(config.cards.first?.goal, 8)
    }
    func testPersonalizationRoundTripAndFreeVisibility() throws {
        let card = DashboardCard(id: .steps, size: .large, tint: .pink, surface: .gradient, presentation: .line, goal: 12000)
        let config = DashboardConfiguration(cards: [card])
        XCTAssertEqual(try JSONDecoder().decode(DashboardConfiguration.self, from: JSONEncoder().encode(config)), config)
        let free = try XCTUnwrap(config.visibleCards(isPro: false).first)
        XCTAssertEqual(free.size, .medium)
        XCTAssertEqual(free.tint, .pink)
        XCTAssertEqual(free.surface, .gradient)
        XCTAssertEqual(free.presentation, .line)
        XCTAssertEqual(free.goal, 12000)
        XCTAssertEqual(config.cards.first?.size, .large)
    }
    func testFutureStyleFallbackDoesNotLoseCard() throws {
        let json = #"{"id":"heart","size":"future","tint":"future","surface":"future","presentation":"ring","goal":-1}"#
        let card = try JSONDecoder().decode(DashboardCard.self, from: Data(json.utf8))
        XCTAssertEqual(card.id, .heart)
        XCTAssertEqual(card.size, .medium)
        XCTAssertEqual(card.tint, .automatic)
        XCTAssertEqual(card.presentation, .line)
        XCTAssertNil(card.goal)
    }
    func testRingDoesNotInventMissingData() {
        XCTAssertNil(HistoryMath.progress(value: nil, goal: 8000))
        XCTAssertNil(HistoryMath.progress(value: 100, goal: 0))
        XCTAssertNil(HistoryMath.progress(value: .nan, goal: 100))
        XCTAssertEqual(HistoryMath.progress(value: 4000, goal: 8000), 0.5)
        XCTAssertEqual(HistoryMath.progress(value: 10000, goal: 8000), 1)
        XCTAssertEqual(HistoryMath.progress(value: 0, goal: 8000), 0)
    }
    func testMissingValuesExcludedFromAverage() {
        XCTAssertNil(HistoryMath.average([nil, nil]))
        XCTAssertEqual(HistoryMath.average([6, nil, 8]), 7)
        XCTAssertEqual(HistoryMath.average([0, 8]), 4)
    }
    func testPeriodsRespectDaylightSavingAndLeapYear() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Luxembourg")!
        let spring = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 12))!
        let autumn = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12))!
        XCTAssertEqual(HistoryPeriod.day.buckets(containing: spring, calendar: calendar).count, 23)
        XCTAssertEqual(HistoryPeriod.day.buckets(containing: autumn, calendar: calendar).count, 25)
        let leap = calendar.date(from: DateComponents(year: 2024, month: 2, day: 10))!
        XCTAssertEqual(HistoryPeriod.month.buckets(containing: leap, calendar: calendar).count, 29)
        XCTAssertEqual(HistoryPeriod.year.buckets(containing: leap, calendar: calendar).count, 12)
    }
    func testSleepWindowUsesCalendarNoonRatherThanFixed24Hours() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Luxembourg")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 15))!
        let window = HistoryMath.sleepWindow(for: date, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: window.start), 12)
        XCTAssertEqual(calendar.component(.hour, from: window.end), 12)
        XCTAssertEqual(window.duration / 3600, 23)
    }
}
