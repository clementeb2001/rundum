import SwiftUI

@main struct RundumApp: App {
    @StateObject private var state = AppState()
    @StateObject private var calendar = CalendarService()
    @StateObject private var health = HealthService()
    @StateObject private var cloud = CloudService()
    @StateObject private var purchases = PurchaseService()
    @StateObject private var weather = WeatherModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state).environmentObject(calendar).environmentObject(health).environmentObject(cloud).environmentObject(purchases)
                .environmentObject(weather)
                .environment(\.locale, Locale(identifier: state.language.rawValue))
                .preferredColorScheme(state.appearance.colorScheme)
                .tint(Palette.teal)
                .task { state.switchAccount(cloud.session?.user.id); await refresh() }
                .onChange(of: cloud.session?.user.id) { user in state.switchAccount(user); Task { await refresh() } }
                .onChange(of: phase) { phase in if phase == .active { Task { await refresh() } } }
                .onChange(of: state.configuration) { _ in publishWidget() }
                .onChange(of: state.language) { _ in publishWidget() }
                .onChange(of: purchases.isPro) { _ in publishWidget() }
                .onReceive(calendar.$events) { events in WidgetSnapshot.publish(cards: state.configuration.visibleCards(isPro: purchases.isPro), events: events, copy: state.copy) }
        }
    }
    private func refresh() async {
        calendar.load(); await health.load(); await purchases.refresh()
        if state.configuration.visibleCards(isPro: purchases.isPro).contains(where: { $0.id == .weather }) { await weather.refresh() }
        await state.synchronize(cloud: cloud)
        if cloud.session != nil { do { try await cloud.loadCalendars() } catch { cloud.error = error.localizedDescription } }
        WidgetSnapshot.publish(cards: state.configuration.visibleCards(isPro: purchases.isPro), events: calendar.events, copy: state.copy)
    }
    private func publishWidget() { WidgetSnapshot.publish(cards: state.configuration.visibleCards(isPro: purchases.isPro), events: calendar.events, copy: state.copy) }
}

enum Palette {
    static let teal = Color(red: 0.12, green: 0.40, blue: 0.36)
    static let paper = Color(uiColor: .systemGroupedBackground)
    static let peach = Color(red: 0.98, green: 0.85, blue: 0.74)
}
struct RootView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        if state.onboarded {
            TabView {
                DashboardView().tabItem { Label(state.copy("Heute", "Aujourd’hui", "Today"), systemImage: "square.grid.2x2") }
                FamilyView().tabItem { Label(state.copy("Gemeinsam", "Ensemble", "Together"), systemImage: "person.2") }
                SettingsView().tabItem { Label(state.copy.settings, systemImage: "slider.horizontal.3") }
            }
        } else { OnboardingView() }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var cloud: CloudService
    @State var selected: Set<CardKind> = [.calendar, .steps]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack { Brand(); Spacer(); Picker("Language", selection: $state.language) { ForEach(Language.allCases) { Text($0.title).tag($0) } }.labelsHidden() }
                    ZStack {
                        RoundedRectangle(cornerRadius: 36).fill(Palette.teal)
                        VStack(alignment: .leading, spacing: 20) {
                            Image(systemName: "sun.max.fill").font(.system(size: 42)).foregroundStyle(Palette.peach)
                            Text(state.copy("Mehr Überblick.\nMehr Zeit für euch.", "Tout en un regard.\nPlus de temps ensemble.", "A little more clarity.\nMore time together.")).font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(.white)
                            Text(state.copy("Dein Alltag findet hier zusammen.", "Ton quotidien se retrouve ici.", "Bring your everyday life together.")).foregroundStyle(.white.opacity(0.8))
                        }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(state.copy("Was ist dir heute wichtig?", "Qu’est-ce qui compte aujourd’hui ?", "What matters to you today?")).font(.title2.bold())
                        Text(state.copy("Wähle bis zu zwei Karten. Du kannst sie jederzeit ändern.", "Choisis jusqu’à deux cartes. Tu pourras les modifier à tout moment.", "Choose up to two cards. You can change them anytime.")).foregroundStyle(.secondary)
                    }
                    ForEach(CardRegistry.kinds) { kind in
                        Button {
                            if selected.contains(kind) { selected.remove(kind) } else if selected.count < 2 { selected.insert(kind) }
                        } label: {
                            HStack { Image(systemName: kind.symbol).frame(width: 28); Text(state.copy.card(kind)); Spacer(); Image(systemName: selected.contains(kind) ? "checkmark.circle.fill" : "circle") }.padding().background(.background, in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain).accessibilityAddTraits(selected.contains(kind) ? .isSelected : [])
                    }
                    Button {
                        state.configuration = .init(cards: CardRegistry.kinds.filter { selected.contains($0) }.map { .init(id: $0) })
                        state.changed(cloud: cloud); state.onboarded = true
                    } label: { Text(state.copy("Mein Rundum starten", "Découvrir mon Rundum", "Start my Rundum")).frame(maxWidth: .infinity).padding(10) }.buttonStyle(.borderedProminent).controlSize(.large)
                    Text(state.copy("Ohne Konto starten. Datenzugriff entscheidest du später selbst.", "Commence sans compte. Tu choisiras ensuite les accès aux données.", "Start without an account. Choose data permissions when you’re ready.")).font(.footnote).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: 650)
            }.background(Palette.paper)
        }
    }
}
struct Brand: View {
    var body: some View { HStack(spacing: 7) { Image(systemName: "circle.hexagongrid.fill").foregroundStyle(Palette.teal); Text("rundum").font(.system(.title2, design: .rounded, weight: .heavy)) }.accessibilityElement(children: .combine) }
}
