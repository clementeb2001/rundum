import SwiftUI
import EventKit
import HealthKit

@MainActor final class CalendarService: ObservableObject {
    let store = EKEventStore()
    @Published var events: [CalendarItem] = []
    @Published var calendars: [EKCalendar] = []
    @Published var hasAccess = false
    @Published var error: String?
    @Published var selected: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "selectedCalendars") ?? [])
    private var observer: NSObjectProtocol?
    init() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.load() } }
        load()
    }
    func request() async {
        do {
            if #available(iOS 17, *) { hasAccess = try await store.requestFullAccessToEvents() }
            else { hasAccess = try await store.requestAccess(to: .event) }
            load()
        } catch { self.error = error.localizedDescription }
    }
    func load() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17, *) { hasAccess = status == .fullAccess } else { hasAccess = status == .authorized }
        guard hasAccess else { events = []; calendars = []; return }
        calendars = store.calendars(for: .event)
        let chosen = UserDefaults.standard.bool(forKey: "calendarSelectionSet") ? calendars.filter { selected.contains($0.calendarIdentifier) } : calendars
        guard !chosen.isEmpty else { events = []; return }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: chosen))
            .filter { $0.endDate >= Date() }.sorted { $0.startDate < $1.startDate }.map {
                CalendarItem(id: ($0.eventIdentifier ?? UUID().uuidString) + String($0.startDate.timeIntervalSince1970), title: $0.title ?? "", start: $0.startDate, end: $0.endDate, allDay: $0.isAllDay, source: $0.calendar.title)
            }
    }
    func isSelected(_ id: String) -> Bool { !UserDefaults.standard.bool(forKey: "calendarSelectionSet") || selected.contains(id) }
    func toggle(_ id: String, enabled: Bool) {
        if !UserDefaults.standard.bool(forKey: "calendarSelectionSet") { selected = Set(calendars.map(\.calendarIdentifier)) }
        if enabled { selected.insert(id) } else { selected.remove(id) }
        UserDefaults.standard.set(true, forKey: "calendarSelectionSet")
        UserDefaults.standard.set(Array(selected), forKey: "selectedCalendars"); load()
    }
}

@MainActor final class HealthService: ObservableObject {
    let store = HKHealthStore()
    @Published var steps: Double?
    @Published var sleep: Double?
    @Published var heart: Double?
    @Published var workoutMinutes: Double?
    @Published var heartUpdated: Date?
    @Published var weekly: [CardKind: [MetricPoint]] = [:]
    @Published var loading = false
    @Published var error: String?
    @Published var requested = UserDefaults.standard.bool(forKey: "healthRequested")
    var available: Bool { HKHealthStore.isHealthDataAvailable() }
    private var types: Set<HKObjectType> { [HKQuantityType(.stepCount), HKQuantityType(.heartRate), HKCategoryType(.sleepAnalysis), HKObjectType.workoutType()] }
    func request() async {
        guard available else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            requested = true; UserDefaults.standard.set(true, forKey: "healthRequested")
            await load()
        } catch { self.error = error.localizedDescription }
    }
    func load() async {
        guard available && requested, !loading else { return }
        loading = true; error = nil
        defer { loading = false }
        let now = Date(), start = Calendar.current.startOfDay(for: Date())
        // HealthKit deliberately does not reveal read authorization; nil must never be presented as zero.
        steps = await sum(type: HKQuantityType(.stepCount), unit: .count(), start: start, end: now)
        let heartSamples = await samples(type: HKQuantityType(.heartRate), start: start, end: now)
        heart = (heartSamples.last as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        heartUpdated = heartSamples.last?.endDate
        let sleepWindow = HistoryMath.sleepWindow(for: now)
        let sleepStart = sleepWindow.start, sleepEnd = min(sleepWindow.end, now)
        let sleepSamples = await samples(type: HKCategoryType(.sleepAnalysis), start: sleepStart, end: sleepEnd)
        let asleep = sleepSamples.compactMap { $0 as? HKCategorySample }.filter { [1, 3, 4, 5].contains($0.value) }
        sleep = asleep.isEmpty ? nil : SleepMath.hours(intervals: asleep.map { DateInterval(start: $0.startDate, end: $0.endDate) }, within: DateInterval(start: sleepStart, end: sleepEnd))
        let workouts = await samples(type: HKObjectType.workoutType(), start: start, end: now)
        workoutMinutes = workouts.isEmpty ? nil : workouts.compactMap { $0 as? HKWorkout }.reduce(0) { $0 + $1.duration / 60 }
        for kind in [CardKind.steps, .sleep, .heart, .workouts] {
            do { weekly[kind] = try await history(kind: kind, period: .week, date: now).points }
            catch { weekly[kind] = []; self.error = error.localizedDescription }
        }
    }
    private func sum(type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async -> Double? {
        await withCheckedContinuation { continuation in
            store.execute(HKStatisticsQuery(quantityType: type, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end), options: .cumulativeSum) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            })
        }
    }
    private func samples(type: HKSampleType, start: Date, end: Date) async -> [HKSample] {
        await withCheckedContinuation { continuation in
            store.execute(HKSampleQuery(sampleType: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end), limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]) { _, samples, _ in
                continuation.resume(returning: samples ?? [])
            })
        }
    }
}
