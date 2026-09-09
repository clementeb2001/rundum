import Foundation
import HealthKit
import EventKit

struct WorkoutRecord: Identifiable {
    let id: UUID
    let date: Date
    let minutes: Double
    let activity: HKWorkoutActivityType
    let source: String
    func title(_ c: Copy) -> String {
        switch activity {
        case .running: return c("Laufen", "Course", "Running")
        case .walking: return c("Gehen", "Marche", "Walking")
        case .cycling: return c("Radfahren", "Vélo", "Cycling")
        case .swimming: return c("Schwimmen", "Natation", "Swimming")
        case .yoga: return "Yoga"
        case .hiking: return c("Wandern", "Randonnée", "Hiking")
        case .traditionalStrengthTraining, .functionalStrengthTraining: return c("Krafttraining", "Musculation", "Strength training")
        case .highIntensityIntervalTraining: return "HIIT"
        default: return c("Training", "Entraînement", "Workout")
        }
    }
}
struct HealthHistory {
    var points: [MetricPoint] = []
    var workouts: [WorkoutRecord] = []
    var summary: Double?
}

extension HealthService {
    /// Results remain in memory. A missing sample is not evidence of a zero value or permission denial.
    func history(kind: CardKind, period: HistoryPeriod, date: Date) async throws -> HealthHistory {
        guard available && requested else { return .init() }
        let calendar = Calendar.current, now = Date()
        let range = period.interval(containing: date)
        let buckets = period.buckets(containing: date)
        guard range.start < now else { return .init() }
        if kind == .steps || kind == .heart {
            let points = try await quantityHistory(kind: kind, period: period, range: range, buckets: buckets, now: now)
            let known = points.compactMap(\.value)
            let summary = kind == .heart ? HistoryMath.average(points.map(\.value)) : (known.isEmpty ? nil : known.reduce(0, +))
            return .init(points: points, summary: summary)
        }
        if kind == .workouts {
            let values = try await historySamples(type: HKObjectType.workoutType(), start: range.start, end: min(range.end, now))
            let workouts = values.compactMap { $0 as? HKWorkout }.filter { $0.startDate >= range.start && $0.startDate < min(range.end, now) }
            let points = buckets.map { bucket in
                let included = workouts.filter { $0.startDate >= bucket.start && $0.startDate < bucket.end }
                return MetricPoint(date: bucket.start, end: bucket.end, value: included.isEmpty ? nil : included.reduce(0) { $0 + $1.duration / 60 })
            }
            return .init(points: points, workouts: workouts.sorted { $0.startDate > $1.startDate }.map {
                WorkoutRecord(id: $0.uuid, date: $0.startDate, minutes: $0.duration / 60, activity: $0.workoutActivityType, source: $0.sourceRevision.source.name)
            }, summary: workouts.isEmpty ? nil : workouts.reduce(0) { $0 + $1.duration / 60 })
        }
        if kind == .sleep {
            let first = HistoryMath.sleepWindow(for: range.start).start
            let lastDay = calendar.date(byAdding: .day, value: -1, to: range.end)!
            let end = min(HistoryMath.sleepWindow(for: lastDay).end, now)
            guard end > first else { return .init() }
            let samples = try await historySamples(type: HKCategoryType(.sleepAnalysis), start: first, end: end)
            let intervals = samples.compactMap { $0 as? HKCategorySample }.filter { [1, 3, 4, 5].contains($0.value) }.map { DateInterval(start: $0.startDate, end: $0.endDate) }
            func sleep(in window: DateInterval) -> Double? {
                let clippedEnd = min(window.end, now)
                guard clippedEnd > window.start else { return nil }
                let included = intervals.filter { $0.end > window.start && $0.start < clippedEnd }
                guard !included.isEmpty else { return nil }
                return SleepMath.hours(intervals: included, within: DateInterval(start: window.start, end: clippedEnd))
            }
            if period == .day {
                let night = HistoryMath.sleepWindow(for: date)
                var cursor = night.start, points: [MetricPoint] = []
                while cursor < night.end {
                    let next = min(calendar.date(byAdding: .hour, value: 1, to: cursor)!, night.end)
                    let window = DateInterval(start: cursor, end: next)
                    points.append(.init(date: cursor, end: next, value: sleep(in: window))); cursor = next
                }
                return .init(points: points, summary: sleep(in: night))
            }
            var day = range.start, nights: [MetricPoint] = []
            while day < min(range.end, now) {
                let next = calendar.date(byAdding: .day, value: 1, to: day)!
                nights.append(.init(date: day, end: next, value: sleep(in: HistoryMath.sleepWindow(for: day)))); day = next
            }
            let points = period == .year ? buckets.map { bucket in
                MetricPoint(date: bucket.start, end: bucket.end, value: HistoryMath.average(nights.filter { $0.date >= bucket.start && $0.date < bucket.end }.map(\.value)))
            } : nights
            return .init(points: points, summary: HistoryMath.average(nights.map(\.value)))
        }
        return .init()
    }

    private func quantityHistory(kind: CardKind, period: HistoryPeriod, range: DateInterval, buckets: [DateInterval], now: Date) async throws -> [MetricPoint] {
        let type = HKQuantityType(kind == .steps ? .stepCount : .heartRate)
        let unit: HKUnit = kind == .steps ? .count() : .count().unitDivided(by: .minute())
        let option: HKStatisticsOptions = kind == .steps ? .cumulativeSum : .discreteAverage
        var components = DateComponents(); components.setValue(1, for: period.bucketComponent)
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: min(range.end, now))
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate, options: option, anchorDate: range.start, intervalComponents: components)
            query.initialResultsHandler = { [store] query, collection, error in
                defer { store.stop(query) }
                if let error { continuation.resume(throwing: error); return }
                let points = buckets.map { bucket -> MetricPoint in
                    let stat = collection?.statistics(for: bucket.start)
                    let quantity = kind == .steps ? stat?.sumQuantity() : stat?.averageQuantity()
                    return MetricPoint(date: bucket.start, end: bucket.end, value: bucket.start < now ? quantity?.doubleValue(for: unit) : nil)
                }
                continuation.resume(returning: points)
            }
            store.execute(query)
        }
    }
    private func historySamples(type: HKSampleType, start: Date, end: Date) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            store.execute(HKSampleQuery(sampleType: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end), limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, values, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: values ?? []) }
            })
        }
    }
}

extension CalendarService {
    func history(in range: DateInterval) -> [CalendarItem] {
        guard hasAccess else { return [] }
        let chosen = store.calendars(for: .event).filter { isSelected($0.calendarIdentifier) }
        guard !chosen.isEmpty else { return [] }
        return store.events(matching: store.predicateForEvents(withStart: range.start, end: range.end, calendars: chosen))
            .sorted { $0.startDate < $1.startDate }.map {
                CalendarItem(id: ($0.eventIdentifier ?? UUID().uuidString) + String($0.startDate.timeIntervalSince1970), title: $0.title ?? "", start: $0.startDate, end: $0.endDate, allDay: $0.isAllDay, source: $0.calendar.title)
            }
    }
}
