import XCTest
@testable import RundumCore
final class CoreTests: XCTestCase {
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
}
