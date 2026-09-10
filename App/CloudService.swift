import Foundation
import Security

struct CloudSession: Codable {
    var access_token: String
    var refresh_token: String
    var expires_at: Double?
    var user: CloudUser
}
struct CloudUser: Codable { var id: UUID; var email: String? }
struct SharedCalendar: Codable, Identifiable { var id: UUID; var name: String; var owner_id: UUID }
struct SharedEvent: Codable, Identifiable {
    var id: UUID
    var calendar_id: UUID
    var title: String
    var starts_at: Date
    var ends_at: Date
    var created_by: UUID
}
struct RemoteConfiguration: Codable { var user_id: UUID; var configuration: DashboardConfiguration }
private struct LocalCloudConfiguration: Codable { let url: String; let publicKey: String }
enum CloudFailure: LocalizedError {
    case configuration, message(String)
    var errorDescription: String? { switch self { case .configuration: return "Cloud configuration missing (SUPABASE_URL / SUPABASE_ANON_KEY)."; case .message(let text): return text } }
}

enum SessionKeychain {
    static let service = "app.rundum.session"
    static func read() -> Data? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: "current", kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as CFDictionary, &result)
        return status == errSecSuccess ? result as? Data : nil
    }
    static func save(_ data: Data?) throws {
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: "current"] as [CFString: Any]
        guard let data else { SecItemDelete(query as CFDictionary); return }
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if update == errSecItemNotFound {
            var item = query; item[kSecValueData] = data; item[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw CloudFailure.message("Keychain unavailable") }; return
        }
        guard update == errSecSuccess else { throw CloudFailure.message("Keychain unavailable") }
    }
}

enum CloudConfigurationStore {
    private static let service = "app.rundum.cloud-configuration"
    static func read() -> (url: String, key: String)? {
        var result: CFTypeRef?
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: "current", kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as CFDictionary
        guard SecItemCopyMatching(query, &result) == errSecSuccess, let data = result as? Data,
              let value = try? JSONDecoder().decode(LocalCloudConfiguration.self, from: data) else { return nil }
        return (value.url, value.publicKey)
    }
    static func save(url: String, key: String) throws {
        let data = try JSONEncoder().encode(LocalCloudConfiguration(url: url, publicKey: key))
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: "current"] as [CFString: Any]
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if update == errSecItemNotFound {
            var item = query; item[kSecValueData] = data; item[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw CloudFailure.message("Cloud configuration could not be saved") }
        } else if update != errSecSuccess { throw CloudFailure.message("Cloud configuration could not be saved") }
    }
}

@MainActor final class CloudService: ObservableObject {
    @Published private(set) var session: CloudSession?
    @Published var calendars: [SharedCalendar] = []
    @Published var events: [SharedEvent] = []
    @Published var familyEvents: [SharedEvent] = []
    @Published var busy = false
    @Published var error: String?
    private var refreshTask: Task<CloudSession, Error>?
    private var urlString: String { CloudConfigurationStore.read()?.url ?? (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "") }
    private var apiKey: String { CloudConfigurationStore.read()?.key ?? (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? "") }
    var configured: Bool { urlString.hasPrefix("https://") && !apiKey.isEmpty && !apiKey.hasPrefix("$(") }
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let format = ISO8601DateFormatter(); format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = format.date(from: value) { return date }
            format.formatOptions = [.withInternetDateTime]
            guard let date = format.date(from: value) else { throw CloudFailure.message("Invalid date") }; return date
        }; return decoder
    }
    static var encoder: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; return encoder }
    init() { if let data = SessionKeychain.read() { session = try? JSONDecoder().decode(CloudSession.self, from: data) } }
    func configure(url rawURL: String, publicKey rawKey: String) throws {
        let url = rawURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = URL(string: url), value.scheme == "https", let host = value.host, host.hasSuffix(".supabase.co") else { throw CloudFailure.message("Bitte die HTTPS-Projekt-URL von Supabase eingeben.") }
        guard PublicCloudKeyValidation.accepts(key) else { throw CloudFailure.message("Nur einen öffentlichen publishable- oder anon-Schlüssel verwenden. Niemals service_role.") }
        try CloudConfigurationStore.save(url: url, key: key); objectWillChange.send(); error = nil
    }
    private func persist(_ value: CloudSession) throws { try SessionKeychain.save(JSONEncoder().encode(value)); session = value }
    func signIn(email: String, password: String, register: Bool) async throws -> Bool {
        let data = try await request(register ? "/auth/v1/signup" : "/auth/v1/token?grant_type=password", method: "POST", body: JSONSerialization.data(withJSONObject: ["email": email, "password": password]), authenticated: false)
        if let session = try? Self.decoder.decode(CloudSession.self, from: data) { try persist(session); return true }
        if register { return false }
        throw CloudFailure.message("Invalid authentication response")
    }
    func signInWithApple(identityToken: Data, nonce: String) async throws {
        guard let token = String(data: identityToken, encoding: .utf8), !token.isEmpty else {
            throw CloudFailure.message("Apple hat kein gültiges Anmelde-Token geliefert.")
        }
        let body = try JSONSerialization.data(withJSONObject: ["provider": "apple", "id_token": token, "nonce": nonce])
        let data = try await request("/auth/v1/token?grant_type=id_token", method: "POST", body: body, authenticated: false)
        try persist(Self.decoder.decode(CloudSession.self, from: data))
    }
    func signOut() async {
        _ = try? await request("/auth/v1/logout", method: "POST")
        try? SessionKeychain.save(nil); session = nil; calendars = []; events = []; familyEvents = []
    }
    func deleteAccount() async throws {
        _ = try await request("/rest/v1/rpc/delete_own_account", method: "POST", body: Data("{}".utf8))
        try SessionKeychain.save(nil); session = nil; calendars = []; events = []; familyEvents = []
    }
    private func token() async throws -> String {
        guard let session else { throw CloudFailure.message("Please sign in") }
        if (session.expires_at ?? 0) > Date().timeIntervalSince1970 + 60 { return session.access_token }
        if let refreshTask { return try await refreshTask.value.access_token }
        let task = Task { () throws -> CloudSession in
            let data = try await request("/auth/v1/token?grant_type=refresh_token", method: "POST", body: JSONSerialization.data(withJSONObject: ["refresh_token": session.refresh_token]), authenticated: false)
            return try Self.decoder.decode(CloudSession.self, from: data)
        }
        refreshTask = task
        defer { refreshTask = nil }
        let updated = try await task.value
        guard self.session?.refresh_token == session.refresh_token else { throw CancellationError() }
        try persist(updated); return updated.access_token
    }
    func request(_ path: String, method: String = "GET", body: Data? = nil, authenticated: Bool = true, prefer: String? = nil) async throws -> Data {
        guard configured, let url = URL(string: urlString + path) else { throw CloudFailure.configuration }
        var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 25
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        if authenticated { request.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw CloudFailure.message(object?["msg"] as? String ?? object?["message"] as? String ?? object?["error_description"] as? String ?? "Network request failed")
        }; return data
    }
    func pullConfiguration() async throws -> DashboardConfiguration? {
        guard let user = session?.user.id else { return nil }
        let data = try await request("/rest/v1/dashboard_configs?user_id=eq.\(user.uuidString)&select=*")
        return try Self.decoder.decode([RemoteConfiguration].self, from: data).first?.configuration
    }
    func pushConfiguration(_ config: DashboardConfiguration) async throws {
        guard let user = session?.user.id else { return }
        _ = try await request("/rest/v1/dashboard_configs?on_conflict=user_id", method: "POST", body: Self.encoder.encode(RemoteConfiguration(user_id: user, configuration: config)), prefer: "resolution=merge-duplicates")
    }
    func loadCalendars() async throws {
        let user = session?.user.id
        let data = try await request("/rest/v1/shared_calendars?select=*&order=name")
        let loadedCalendars = try Self.decoder.decode([SharedCalendar].self, from: data)
        let start = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        let end = ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: 7, to: Date())!)
        let eventsData = try await request("/rest/v1/shared_events?select=*&ends_at=gte.\(start)&starts_at=lt.\(end)&order=starts_at")
        guard user == session?.user.id else { return }
        calendars = loadedCalendars
        events = try Self.decoder.decode([SharedEvent].self, from: eventsData)
    }
    /// Loads shared events for an arbitrary range (used by the Together calendar view, which browses whole months).
    func loadFamilyEvents(in range: DateInterval) async throws {
        let user = session?.user.id
        let start = ISO8601DateFormatter().string(from: range.start)
        let end = ISO8601DateFormatter().string(from: range.end)
        let data = try await request("/rest/v1/shared_events?select=*&ends_at=gte.\(start)&starts_at=lt.\(end)&order=starts_at")
        guard user == session?.user.id else { return }
        familyEvents = try Self.decoder.decode([SharedEvent].self, from: data)
    }
    func createCalendar(name: String) async throws {
        _ = try await request("/rest/v1/rpc/create_shared_calendar", method: "POST", body: JSONSerialization.data(withJSONObject: ["calendar_name": name]))
        try await loadCalendars()
    }
    func invite(calendar: UUID) async throws -> String {
        let data = try await request("/rest/v1/rpc/create_calendar_invite", method: "POST", body: JSONSerialization.data(withJSONObject: ["target_calendar": calendar.uuidString]))
        return try Self.decoder.decode(String.self, from: data)
    }
    func join(code: String) async throws {
        _ = try await request("/rest/v1/rpc/join_calendar", method: "POST", body: JSONSerialization.data(withJSONObject: ["invite_code": code.trimmingCharacters(in: .whitespacesAndNewlines)]))
        try await loadCalendars()
    }
    func addEvent(calendar: UUID, title: String, start: Date, end: Date) async throws {
        guard let user = session?.user.id else { return }
        _ = try await request("/rest/v1/shared_events", method: "POST", body: Self.encoder.encode(SharedEvent(id: UUID(), calendar_id: calendar, title: title, starts_at: start, ends_at: end, created_by: user)))
        try await loadCalendars()
    }
    func deleteEvent(_ event: SharedEvent) async throws {
        _ = try await request("/rest/v1/shared_events?id=eq.\(event.id.uuidString)", method: "DELETE"); try await loadCalendars()
    }
    func updateEvent(_ event: SharedEvent, title: String, start: Date, end: Date) async throws {
        struct Changes: Encodable { let title: String; let starts_at: Date; let ends_at: Date }
        _ = try await request("/rest/v1/shared_events?id=eq.\(event.id.uuidString)", method: "PATCH", body: Self.encoder.encode(Changes(title: title, starts_at: start, ends_at: end)))
        try await loadCalendars()
    }
    func leaveCalendar(_ calendar: SharedCalendar) async throws {
        _ = try await request("/rest/v1/rpc/leave_calendar", method: "POST", body: JSONSerialization.data(withJSONObject: ["target_calendar": calendar.id.uuidString])); try await loadCalendars()
    }
}
