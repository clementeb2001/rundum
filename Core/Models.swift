import Foundation

public struct CardKind: RawRepresentable, Codable, Hashable, Identifiable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let calendar = Self(rawValue: "calendar")
    public static let steps = Self(rawValue: "steps")
    public static let sleep = Self(rawValue: "sleep")
    public static let heart = Self(rawValue: "heart")
    public static let workouts = Self(rawValue: "workouts")
    public static let weather = Self(rawValue: "weather")
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(rawValue) }
    public var id: String { rawValue }
    public var symbol: String {
        switch self { case .calendar: return "calendar"; case .steps: return "figure.walk"; case .sleep: return "moon.stars.fill"; case .heart: return "heart.fill"; case .workouts: return "figure.run"; case .weather: return "cloud.sun.fill"; default: return "square.grid.2x2" }
    }
}
public enum CardSize: String, Codable, CaseIterable { case small, medium, large }
public enum CardWidth: String, Codable, CaseIterable { case full, half }
public enum CardTint: String, Codable, CaseIterable { case automatic, coral, orange, gold, green, teal, blue, indigo, pink }
public enum CardSurface: String, Codable, CaseIterable { case plain, tinted, gradient }
public enum CardPresentation: String, Codable, CaseIterable { case value, bars, line, ring, agenda }
public extension CardKind {
    var presentations: [CardPresentation] {
        switch self {
        case .calendar: return [.agenda]
        case .sleep: return [.ring, .value]
        case .weather: return [.value, .line, .bars]
        case .heart: return [.line, .bars, .value]
        default: return [.ring, .bars, .line, .value]
        }
    }
    var defaultPresentation: CardPresentation {
        switch self { case .calendar: return .agenda; case .weather: return .value; case .heart: return .line; default: return .ring }
    }
    var defaultGoal: Double? {
        switch self { case .steps: return 8000; case .sleep: return 8; case .workouts: return 30; default: return nil }
    }
}
public struct DashboardCard: Codable, Identifiable, Equatable {
    public var id: CardKind
    public var size: CardSize
    public var width: CardWidth
    public var tint: CardTint
    public var surface: CardSurface
    public var presentation: CardPresentation
    public var goal: Double?
    public init(id: CardKind, size: CardSize = .medium, tint: CardTint = .automatic, surface: CardSurface? = nil, presentation: CardPresentation? = nil, goal: Double? = nil, width: CardWidth = .full) {
        self.id = id; self.size = size; self.tint = tint; self.width = width
        self.surface = surface ?? (id == .weather ? .gradient : .plain)
        self.presentation = presentation ?? id.defaultPresentation
        self.goal = goal ?? id.defaultGoal
    }
    private enum CodingKeys: String, CodingKey { case id, size, width, tint, surface, presentation, goal }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(CardKind.self, forKey: .id)
        self.init(id: kind,
                  size: (try? c.decode(CardSize.self, forKey: .size)) ?? .medium,
                  tint: (try? c.decode(CardTint.self, forKey: .tint)) ?? .automatic,
                  surface: try? c.decode(CardSurface.self, forKey: .surface),
                  presentation: try? c.decode(CardPresentation.self, forKey: .presentation),
                  goal: try? c.decode(Double.self, forKey: .goal),
                  width: (try? c.decode(CardWidth.self, forKey: .width)) ?? .full)
        if !kind.presentations.contains(presentation) { presentation = kind.defaultPresentation }
        if let goal, !goal.isFinite || goal <= 0 { self.goal = kind.defaultGoal }
    }
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
        isPro ? cards : Array(cards.prefix(2)).map { var card = $0; card.size = .medium; return card }
    }
}

public enum HistoryPeriod: String, CaseIterable, Identifiable {
    case day, week, month, year
    public var id: String { rawValue }
    public var component: Calendar.Component {
        switch self { case .day: return .day; case .week: return .weekOfYear; case .month: return .month; case .year: return .year }
    }
    public var bucketComponent: Calendar.Component {
        switch self { case .day: return .hour; case .week, .month: return .day; case .year: return .month }
    }
    public func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: component, for: date)!
    }
    public func buckets(containing date: Date, calendar: Calendar = .current) -> [DateInterval] {
        let range = interval(containing: date, calendar: calendar)
        var start = range.start, result: [DateInterval] = []
        while start < range.end {
            guard let next = calendar.date(byAdding: bucketComponent, value: 1, to: start), next > start else { break }
            result.append(DateInterval(start: start, end: min(next, range.end))); start = next
        }
        return result
    }
}
public struct MetricPoint: Identifiable, Equatable {
    public var date: Date
    public var end: Date
    public var value: Double?
    public var id: Date { date }
    public init(date: Date, end: Date, value: Double?) { self.date = date; self.end = end; self.value = value }
}
public enum HistoryMath {
    public static func progress(value: Double?, goal: Double?) -> Double? {
        guard let value, value.isFinite, let goal, goal.isFinite, goal > 0 else { return nil }
        return min(max(value / goal, 0), 1)
    }
    public static func average(_ values: [Double?]) -> Double? {
        let known = values.compactMap { $0 }.filter(\.isFinite)
        return known.isEmpty ? nil : known.reduce(0, +) / Double(known.count)
    }
    /// A night's sleep belongs to the date on which its noon-to-noon window ends.
    public static func sleepWindow(for day: Date, calendar: Calendar = .current) -> DateInterval {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        return DateInterval(start: calendar.date(byAdding: .day, value: -1, to: noon)!, end: noon)
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

public struct CalendarTimelinePlacement {
    public let event: CalendarItem
    public let start: Date
    public let end: Date
    public var lane: Int
    public var lanes: Int
}
public enum CalendarTimelineLayout {
    /// Clip to this local day. Use minimum visual height when resolving overlaps.
    public static func placements(events: [CalendarItem], day: Date, calendar: Calendar = .current) -> [CalendarTimelinePlacement] {
        let range = HistoryPeriod.day.interval(containing: day, calendar: calendar)
        let sorted = events.filter { !$0.allDay && $0.start < range.end && $0.end > range.start }
            .sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
        var result: [CalendarTimelinePlacement] = [], group: [CalendarTimelinePlacement] = [], laneEnds: [Date] = []
        func flush() {
            let count = laneEnds.count
            result += group.map { var value = $0; value.lanes = count; return value }
            group = []; laneEnds = []
        }
        for event in sorted {
            let start = max(event.start, range.start)
            let end = min(max(event.end, start.addingTimeInterval(1800)), range.end)
            if let last = laneEnds.max(), start >= last { flush() }
            let lane = laneEnds.firstIndex { $0 <= start } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(end) } else { laneEnds[lane] = end }
            group.append(.init(event: event, start: start, end: end, lane: lane, lanes: 1))
        }
        flush(); return result
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
