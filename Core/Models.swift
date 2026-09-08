import Foundation

public struct CardKind: RawRepresentable, Codable, Hashable, Identifiable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let calendar = Self(rawValue: "calendar")
    public static let steps = Self(rawValue: "steps")
    public static let sleep = Self(rawValue: "sleep")
    public static let heart = Self(rawValue: "heart")
    public static let workouts = Self(rawValue: "workouts")
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(rawValue) }
    public var id: String { rawValue }
    public var symbol: String {
        switch self { case .calendar: return "calendar"; case .steps: return "figure.walk"; case .sleep: return "moon.stars.fill"; case .heart: return "heart.fill"; case .workouts: return "figure.run"; default: return "square.grid.2x2" }
    }
}
public enum CardSize: String, Codable, CaseIterable { case small, medium, large }
public struct DashboardCard: Codable, Identifiable, Equatable {
    public var id: CardKind
    public var size: CardSize
    public init(id: CardKind, size: CardSize = .medium) { self.id = id; self.size = size }
}
public struct DashboardConfiguration: Codable, Equatable {
    public var cards: [DashboardCard]
    public var updatedAt: Date
    public init(cards: [DashboardCard] = [.init(id: .calendar), .init(id: .steps)]) {
        self.cards = cards; updatedAt = Date()
    }
    public mutating func setEnabled(_ kind: CardKind, enabled: Bool, isPro: Bool) -> Bool {
        if enabled && !cards.contains(where: { $0.id == kind }) {
            guard isPro || cards.count < 2 else { return false }
            cards.append(.init(id: kind))
        } else if !enabled { cards.removeAll { $0.id == kind } }
        updatedAt = Date(); return true
    }
    public func visibleCards(isPro: Bool) -> [DashboardCard] {
        isPro ? cards : Array(cards.prefix(2)).map { .init(id: $0.id, size: .medium) }
    }
}
public struct CalendarItem: Identifiable, Codable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var allDay: Bool
    public var source: String
    public init(id: String, title: String, start: Date, end: Date, allDay: Bool, source: String) {
        self.id = id; self.title = title; self.start = start; self.end = end; self.allDay = allDay; self.source = source
    }
}
public enum SleepMath {
    /// Merge overlapping sources (e.g. watch + ring) instead of double counting sleep.
    public static func hours(intervals: [DateInterval], within window: DateInterval) -> Double {
        let clipped = intervals.compactMap { interval -> DateInterval? in
            let start = max(interval.start, window.start), end = min(interval.end, window.end)
            return end > start ? DateInterval(start: start, end: end) : nil
        }.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var current: DateInterval?
        for interval in clipped {
            if let previous = current {
                if interval.start <= previous.end { current = DateInterval(start: previous.start, end: max(previous.end, interval.end)) }
                else { total += previous.duration; current = interval }
            } else { current = interval }
        }
        return (total + (current?.duration ?? 0)) / 3600
    }
}
