import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var health: HealthService
    @EnvironmentObject var cloud: CloudService
    @EnvironmentObject var purchases: PurchaseService
    @EnvironmentObject var weather: WeatherModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var library = false
    @State private var dragging: CardKind?
    @State private var styling: DashboardCard?
    private var allEvents: [CalendarItem] {
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return (calendar.events + cloud.events.map { event in CalendarItem(id: event.id.uuidString, title: event.title, start: event.starts_at, end: event.ends_at, allDay: false, source: cloud.calendars.first { $0.id == event.calendar_id }?.name ?? "Rundum") }).filter { $0.end >= now && $0.start < end }.sorted { $0.start < $1.start }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { Brand(); Spacer(); Button { library = true } label: { Image(systemName: "slider.horizontal.3").padding(12).background(.background, in: Circle()) }.accessibilityLabel(state.copy("Dashboard anpassen", "Personnaliser le tableau de bord", "Customize dashboard")).accessibilityIdentifier("dashboard-customize") }
                    VStack(alignment: .leading, spacing: 7) {
                        Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide)).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        Text(state.copy("Hallo, neuer Tag.", "Bonjour, nouvelle journée.", "Hello, new day.")).font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(state.copy("Alles Wichtige. An deinem Platz.", "L’essentiel. Au même endroit.", "Everything that matters. In your space.")).foregroundStyle(.secondary)
                    }
                    if let error = state.syncError { Notice(text: state.copy("Offline gespeichert. Synchronisierung ausstehend: ", "Enregistré localement. Synchronisation en attente : ", "Saved locally. Sync pending: ") + error) }
                    if state.configuration.cards.isEmpty {
                        VStack(spacing: 14) { Image(systemName: "square.grid.2x2").font(.largeTitle); Text(state.copy("Hier beginnt dein Überblick.", "Ton aperçu commence ici.", "Your overview starts here.")); Button(state.copy("Karten auswählen", "Choisir les cartes", "Choose cards")) { library = true } }.frame(maxWidth: .infinity).padding(32).background(.background, in: RoundedRectangle(cornerRadius: 24))
                    }
                    DashboardWidgetLayout(singleColumn: typeSize.isAccessibilitySize) { ForEach(state.configuration.visibleCards(isPro: purchases.isPro)) { card in
                        VStack(spacing: 10) {
                            if (card.width == .half && !typeSize.isAccessibilitySize) || (card.id == .calendar && card.presentation == .value) {
                                NavigationLink {
                                    if card.id == .weather { WeatherDetailView() } else { CardDetailView(kind: card.id) }
                                } label: { CompactDashboardCard(card: card, events: allEvents) }.buttonStyle(.plain).accessibilityIdentifier("dashboard-card-" + card.id.rawValue)
                            } else if card.id == .calendar {
                                RichMetricCardView(card: card, events: cloud.events.map { event in
                                    CalendarItem(id: event.id.uuidString, title: event.title, start: event.starts_at, end: event.ends_at, allDay: false, source: cloud.calendars.first { $0.id == event.calendar_id }?.name ?? "Rundum")
                                }, interactiveCalendar: true)
                            } else {
                            NavigationLink {
                                if card.id == .weather { WeatherDetailView() }
                                else { CardDetailView(kind: card.id) }
                            } label: {
                                CardRegistry.render(card: card, events: allEvents)
                            }.buttonStyle(.plain).accessibilityIdentifier("dashboard-card-" + card.id.rawValue)
                            }
                            if card.id == .weather { WeatherCredits(compact: card.width == .half).padding(.horizontal, card.width == .half ? 0 : 12) }
                        }
                            .padding(.bottom, 24)
                            .overlay(alignment: .bottomTrailing) {
                                CardResizeHandle(card: card) { width in
                                    guard let index = state.configuration.cards.firstIndex(where: { $0.id == card.id }) else { return }
                                    withAnimation(.easeInOut(duration: 0.2)) { state.configuration.cards[index].width = width }
                                    state.changed(cloud: cloud)
                                }
                            }
                            .layoutValue(key: HalfCardLayoutKey.self, value: card.width == .half)
                            .contextMenu { Button { styling = card } label: { Label(state.copy("Karte gestalten", "Personnaliser la carte", "Customize card"), systemImage: "paintpalette") } }
                            .onDrag { dragging = card.id; return NSItemProvider(object: card.id.rawValue as NSString) }
                            .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                                guard !providers.isEmpty, let dragging, dragging != card.id,
                                      let from = state.configuration.cards.firstIndex(where: { $0.id == dragging }), let to = state.configuration.cards.firstIndex(where: { $0.id == card.id }) else { return false }
                                withAnimation { state.configuration.cards.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to) }
                                self.dragging = nil; state.changed(cloud: cloud); return true
                            }
                    } }
                    Button { library = true } label: { Label(state.copy("Dein Dashboard gestalten", "Personnaliser ton tableau de bord", "Make this dashboard yours"), systemImage: "plus.circle").frame(maxWidth: .infinity).padding(18) }.background(Palette.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                    Text(state.copy("Gesundheitsdaten bleiben auf deinem iPhone.", "Tes données de santé restent sur ton iPhone.", "Your health data stays on your iPhone.")).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.padding(22).frame(maxWidth: 760)
            }.background(Palette.paper).toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $library) { CardLibraryView() }
                .sheet(item: $styling) { CardCustomizationView(kind: $0.id) }
                .refreshable {
                    if state.configuration.visibleCards(isPro: purchases.isPro).contains(where: { $0.id == .weather }) { await weather.refresh(force: true) }
                    calendar.load(); await health.load(); await state.synchronize(cloud: cloud)
                    if cloud.session != nil { do { try await cloud.loadCalendars() } catch { cloud.error = error.localizedDescription } }
                    WidgetSnapshot.publish(cards: state.configuration.visibleCards(isPro: purchases.isPro), events: calendar.events, copy: state.copy)
                }
        }
    }
}

struct HalfCardLayoutKey: LayoutValueKey { static let defaultValue = false }

/// A dedicated target keeps resizing separate from card navigation and timeline scrolling.
struct CardResizeHandle: View {
    let card: DashboardCard
    let resize: (CardWidth) -> Void
    @EnvironmentObject var state: AppState
    @GestureState private var translation: CGFloat = 0
    var body: some View {
        Image(systemName: "arrow.left.and.right")
            .font(.caption.weight(.semibold)).foregroundStyle(card.accent)
            .frame(width: 44, height: 44)
            .background(card.accent.opacity(translation == 0 ? 0.08 : 0.2), in: Capsule())
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .updating($translation) { value, offset, _ in offset = value.translation.width }
                .onEnded { value in
                    if value.translation.width < -40 { resize(.half) }
                    else if value.translation.width > 40 { resize(.full) }
                })
            .accessibilityElement()
            .accessibilityLabel(state.copy("Kartenbreite ändern", "Modifier la largeur", "Resize card width"))
            .accessibilityValue(card.width == .half ? state.copy("Halb", "Moitié", "Half") : state.copy("Ganz", "Entière", "Full"))
            .accessibilityHint(state.copy("Nach links ziehen für halb, nach rechts für ganz.", "Glisser à gauche pour moitié, à droite pour pleine largeur.", "Drag left for half, right for full width."))
            .accessibilityAdjustableAction { direction in
                switch direction { case .increment: resize(.full); case .decrement: resize(.half); @unknown default: break }
            }
            .accessibilityIdentifier("resize-card-" + card.id.rawValue)
    }
}
/// Packs adjacent half-width cards together without changing the user's order.
struct DashboardWidgetLayout: Layout {
    var singleColumn = false
    private let gap: CGFloat = 14
    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        var frames: [CGRect] = [], index = 0, y: CGFloat = 0
        while index < subviews.count {
            let half = subviews[index][HalfCardLayoutKey.self] && !singleColumn
            let cellWidth = half ? max(1, (width - gap) / 2) : width
            let firstHeight = subviews[index].sizeThatFits(.init(width: cellWidth, height: nil)).height
            let paired = half && index + 1 < subviews.count && subviews[index + 1][HalfCardLayoutKey.self]
            let secondHeight = paired ? subviews[index + 1].sizeThatFits(.init(width: cellWidth, height: nil)).height : 0
            let height = max(firstHeight, secondHeight)
            frames.append(.init(x: 0, y: y, width: cellWidth, height: firstHeight))
            if paired { frames.append(.init(x: cellWidth + gap, y: y, width: cellWidth, height: secondHeight)) }
            y += height + gap; index += paired ? 2 : 1
        }
        return frames
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        return .init(width: width, height: frames(width: width, subviews: subviews).map(\.maxY).max() ?? 0)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, frame) in frames(width: bounds.width, subviews: subviews).enumerated() {
            subviews[index].place(at: .init(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading, proposal: .init(width: frame.width, height: frame.height))
        }
    }
}

struct Notice: View { let text: String; var body: some View { Label(text, systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary).accessibilityElement(children: .combine) } }

struct CardLibraryView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var cloud: CloudService
    @EnvironmentObject var purchases: PurchaseService
    @Environment(\.dismiss) var dismiss
    @State var pro = false
    var body: some View {
        NavigationStack {
            List {
                Section(state.copy("Deine Karten · ziehen zum Sortieren", "Tes cartes · glisser pour trier", "Your cards · drag to reorder")) {
                    ForEach(state.configuration.cards) { card in
                        NavigationLink { CardCustomizationView(kind: card.id, embedded: true) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: card.id.symbol).font(.title2).foregroundStyle(card.accent).frame(width: 40, height: 44)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(state.copy.card(card.id)).font(.headline).foregroundStyle(.primary)
                                    Text(state.copy.title(card.presentation) + " · " + state.copy.title(card.tint)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "paintpalette").foregroundStyle(card.accent)
                            }.padding(.vertical, 5)
                        }.buttonStyle(.plain).accessibilityIdentifier("customize-card-" + card.id.rawValue)
                    }.onMove { from, to in state.configuration.cards.move(fromOffsets: from, toOffset: to); state.changed(cloud: cloud) }
                        .onDelete { offsets in state.configuration.cards.remove(atOffsets: offsets); state.changed(cloud: cloud) }
                }
                Section(state.copy("Bibliothek", "Bibliothèque", "Library")) {
                    ForEach(CardRegistry.kinds) { kind in
                        Toggle(isOn: Binding(get: { state.configuration.cards.contains { $0.id == kind } }, set: { enabled in
                            if state.configuration.setEnabled(kind, enabled: enabled, isPro: purchases.isPro) { state.changed(cloud: cloud) } else { pro = true }
                        })) { Label(state.copy.card(kind), systemImage: kind.symbol) }.accessibilityIdentifier("enable-card-" + kind.rawValue)
                    }
                }
                if !purchases.isPro {
                    Section { Button("Rundum Pro") { pro = true }; Text(state.copy("Gratis: 2 aktive Karten. Pro: alle Karten und zusätzliche Größen.", "Gratuit : 2 cartes actives. Pro : toutes les cartes et tailles supplémentaires.", "Free: 2 active cards. Pro: all cards and extra sizes.")).font(.footnote) }
                }
            }.navigationTitle(state.copy("Dein Dashboard", "Ton tableau de bord", "Your dashboard"))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(state.copy("Fertig", "Terminé", "Done")) { dismiss() } }; ToolbarItem(placement: .navigationBarLeading) { EditButton() } }
                .sheet(isPresented: $pro) { ProView() }
        }
    }
}
