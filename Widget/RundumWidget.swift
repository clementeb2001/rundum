import WidgetKit
import SwiftUI

struct RundumEntry: TimelineEntry { let date: Date; let title: String; let subtitle: String; let event: Date? }
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> RundumEntry { .init(date: Date(), title: "Rundum", subtitle: "Dein Tag, auf einen Blick.", event: nil) }
    func getSnapshot(in context: Context, completion: @escaping (RundumEntry) -> Void) { completion(read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RundumEntry>) -> Void) {
        let entry = read()
        // Expire the persisted title at the event start even if the app has not been opened.
        let refresh = min(entry.event ?? .distantFuture, Date().addingTimeInterval(1800))
        completion(Timeline(entries: [entry], policy: .after(max(refresh, Date().addingTimeInterval(60)))))
    }
    func read() -> RundumEntry {
        let group = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String ?? "group.app.rundum"
        let data = UserDefaults(suiteName: group)
        let stamp = data?.double(forKey: "eventStart") ?? 0
        let upcoming = stamp > Date().timeIntervalSince1970 ? Date(timeIntervalSince1970: stamp) : nil
        return .init(date: Date(), title: upcoming != nil ? (data?.string(forKey: "headline") ?? "Rundum") : "Rundum", subtitle: data?.string(forKey: "subtitle") ?? "Rundum", event: upcoming)
    }
}
struct WidgetBody: View {
    let entry: RundumEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("rundum", systemImage: "circle.hexagongrid.fill").font(.headline)
            Spacer(minLength: 0)
            Text(entry.title).font(.system(.title3, design: .rounded, weight: .bold)).lineLimit(3).privacySensitive()
            if let event = entry.event { Text(event, style: .time).font(.subheadline).privacySensitive() }
            else { Text(entry.subtitle).font(.caption) }
        }.foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
    }
}
@main struct RundumHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RundumHome", provider: Provider()) { entry in
            if #available(iOSApplicationExtension 17, *) { WidgetBody(entry: entry).containerBackground(Color(red: 0.12, green: 0.40, blue: 0.36), for: .widget) }
            else { WidgetBody(entry: entry).padding().background(Color(red: 0.12, green: 0.40, blue: 0.36)) }
        }.configurationDisplayName("Rundum").description("Dein nächster Termin. / Ton prochain rendez-vous. / Your next event.").supportedFamilies([.systemSmall, .systemMedium])
    }
}
