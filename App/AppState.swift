import SwiftUI
import StoreKit
import WidgetKit

@MainActor final class PurchaseService: ObservableObject {
    @Published var isPro = false
    @Published var product: Product?
    @Published var error: String?
    private var listener: Task<Void, Never>?
    private var productID: String { Bundle.main.object(forInfoDictionaryKey: "PRO_PRODUCT_ID") as? String ?? "app.rundum.pro.monthly" }
    init() {
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await self?.refresh(); await transaction.finish() }
            }
        }
        Task { await refresh(); await loadProduct() }
    }
    func loadProduct() async { do { product = try await Product.products(for: [productID]).first } catch { self.error = error.localizedDescription } }
    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == productID, transaction.revocationDate == nil, (transaction.expirationDate ?? .distantFuture) > Date() { active = true }
        }; isPro = active
    }
    func buy() async {
        guard let product else { return }
        do {
            if case .success(.verified(let transaction)) = try await product.purchase() { await refresh(); await transaction.finish() }
        } catch { self.error = error.localizedDescription }
    }
    func restore() async { do { try await AppStore.sync(); await refresh() } catch { self.error = error.localizedDescription } }
}

@MainActor final class AppState: ObservableObject {
    @Published var configuration: DashboardConfiguration
    @Published var syncError: String?
    @Published var syncing = false
    @Published var language: Language { didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") } }
    @Published var onboarded: Bool { didSet { UserDefaults.standard.set(onboarded, forKey: "onboarded") } }
    private var storageKey = "dashboard.guest"
    private var syncTask: Task<Void, Never>?
    var copy: Copy { Copy(language: language) }
    init() {
        language = Language(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .initial
        onboarded = UserDefaults.standard.bool(forKey: "onboarded")
        configuration = Self.read("dashboard.guest") ?? .init()
    }
    private static func read(_ key: String) -> DashboardConfiguration? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(DashboardConfiguration.self, from: $0) }
    }
    private func persist() { if let data = try? JSONEncoder().encode(configuration) { UserDefaults.standard.set(data, forKey: storageKey) } }
    func switchAccount(_ user: UUID?) {
        syncTask?.cancel()
        storageKey = user.map { "dashboard.\($0.uuidString)" } ?? "dashboard.guest"
        configuration = Self.read(storageKey) ?? .init()
        syncError = nil
    }
    func changed(cloud: CloudService) {
        configuration.updatedAt = Date(); persist()
        syncTask?.cancel()
        guard cloud.session != nil else { return }
        let snapshot = configuration, key = storageKey
        syncTask = Task {
            do {
                try await Task.sleep(nanoseconds: 700_000_000)
                guard !Task.isCancelled, key == storageKey else { return }
                try await cloud.pushConfiguration(snapshot)
                if key == storageKey { syncError = nil }
            } catch is CancellationError {} catch { if key == storageKey { syncError = error.localizedDescription } }
        }
    }
    func synchronize(cloud: CloudService) async {
        guard cloud.session != nil, !syncing else { return }
        syncing = true; defer { syncing = false }
        let key = storageKey, before = configuration
        do {
            let remote = try await cloud.pullConfiguration()
            guard key == storageKey, before == configuration else { return }
            if let remote, remote.updatedAt > configuration.updatedAt || Self.read(key) == nil { configuration = remote; persist() }
            else { try await cloud.pushConfiguration(configuration) }
            syncError = nil
        } catch { syncError = error.localizedDescription }
    }
}

enum WidgetSnapshot {
    static var group: String { Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String ?? "group.app.rundum" }
    static func publish(cards: [DashboardCard], events: [CalendarItem], copy: Copy) {
        guard let defaults = UserDefaults(suiteName: group) else { return }
        // Only calendar data explicitly opted into the lock-screen/home-screen snapshot.
        let allowed = UserDefaults.standard.bool(forKey: "shareCalendarWithWidget") && cards.contains { $0.id == .calendar }
        let next = allowed ? events.first : nil
        defaults.set(next?.title ?? copy("Dein Tag, auf einen Blick.", "Ta journée, en un coup d’œil.", "Your day, at a glance."), forKey: "headline")
        defaults.set(next?.start.timeIntervalSince1970, forKey: "eventStart")
        defaults.set(copy("Rundum öffnen", "Ouvrir Rundum", "Open Rundum"), forKey: "subtitle")
        defaults.set(Date().timeIntervalSince1970, forKey: "updatedAt")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
