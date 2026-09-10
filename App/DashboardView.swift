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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var library = false
    @State private var editing = false
    @State private var dragging: CardKind?
    @State private var styling: DashboardCard?
    @Namespace private var cardZoom
    private var sharedItems: [CalendarItem] {
        cloud.events.map { event in CalendarItem(id: event.id.uuidString, title: event.title, start: event.starts_at, end: event.ends_at, allDay: false, source: cloud.calendars.first { $0.id == event.calendar_id }?.name ?? "Rundum") }
    }
    private var allEvents: [CalendarItem] {
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let local = state.calendarScope != .shared ? calendar.events : []
        let shared = state.calendarScope != .mine ? sharedItems : []
        return (local + shared).filter { $0.end >= now && $0.start < end }.sorted { $0.start < $1.start }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Brand(); Spacer()
                        Button { withAnimation(.rundumSnappy) { editing.toggle() } } label: {
                            Image(systemName: editing ? "checkmark" : "pencil").frame(width: 44, height: 44).background(.background, in: Circle())
                        }.accessibilityLabel(editing ? state.copy("Fertig", "Terminé", "Done") : state.copy("Dashboard bearbeiten", "Modifier le tableau de bord", "Edit dashboard")).accessibilityIdentifier("dashboard-edit").selectionHaptic(editing)
                        Button { library = true } label: { Image(systemName: "slider.horizontal.3").padding(12).background(.background, in: Circle()) }.accessibilityLabel(state.copy("Dashboard anpassen", "Personnaliser le tableau de bord", "Customize dashboard")).accessibilityIdentifier("dashboard-customize")
                    }
                    if editing {
                        Label(state.copy("Karten halten und verschieben. Die Größe wählst du direkt an der Karte.", "Maintiens et déplace les cartes. Choisis leur taille directement sur la carte.", "Hold and move cards. Choose their size directly on the card."), systemImage: "hand.draw")
                            .font(.footnote).foregroundStyle(.secondary).transition(.move(edge: .top).combined(with: .opacity))
                    }
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
                                    Group { if card.id == .weather { WeatherDetailView() } else { CardDetailView(kind: card.id) } }.zoomDestination(card.id, cardZoom)
                                } label: { CompactDashboardCard(card: card, events: allEvents) }.buttonStyle(.plain).accessibilityIdentifier("dashboard-card-" + card.id.rawValue)
                            } else if card.id == .calendar {
                                RichMetricCardView(card: card, events: state.calendarScope != .mine ? sharedItems : [], interactiveCalendar: true)
                            } else {
                            NavigationLink {
                                Group {
                                    if card.id == .weather { WeatherDetailView() }
                                    else { CardDetailView(kind: card.id) }
                                }.zoomDestination(card.id, cardZoom)
                            } label: {
                                CardRegistry.render(card: card, events: allEvents)
                            }.buttonStyle(.plain).accessibilityIdentifier("dashboard-card-" + card.id.rawValue)
                            }
                        }.allowsHitTesting(!editing)
                            .overlay(alignment: .bottomLeading) {
                                if card.id == .weather { WeatherCredits(compact: true).padding(.leading, 16).padding(.bottom, 4).allowsHitTesting(!editing) }
                            }
                            .overlay {
                                if editing { Color.clear.contentShape(RoundedRectangle(cornerRadius: 24)) }
                            }
                            .overlay(alignment: .topLeading) {
                                if editing {
                                    Button { remove(card) } label: {
                                        Image(systemName: "minus").font(.caption.bold()).foregroundStyle(.white)
                                            .frame(width: 25, height: 25).background(.red, in: Circle()).shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                                    }.offset(x: -7, y: -7).accessibilityLabel(state.copy("Karte entfernen", "Supprimer la carte", "Remove card"))
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if editing { CardEditMenu(card: card, resize: { resize(card, to: $0) }, customize: { styling = card }, remove: { remove(card) }).offset(x: 7, y: -7) }
                            }
                            .layoutValue(key: HalfCardLayoutKey.self, value: card.width == .half)
                            .cardScrollTransition().scaleEffect(dragging == card.id ? 1.035 : 1)
                            .rotationEffect(.degrees(editing && !reduceMotion ? (card.id.rawValue.count.isMultiple(of: 2) ? 0.35 : -0.35) : 0))
                            .animation(editing && !reduceMotion ? .easeInOut(duration: 0.16).repeatForever(autoreverses: true) : .rundumSnappy, value: editing)
                            .zIndex(dragging == card.id ? 2 : 0)
                            .zoomSource(card.id, cardZoom)
                            .contextMenu { Button { styling = card } label: { Label(state.copy("Karte gestalten", "Personnaliser la carte", "Customize card"), systemImage: "paintpalette") } }
                            .onLongPressGesture(minimumDuration: 0.45) { if !editing { withAnimation(.rundumSnappy) { editing = true } } }
                            .onDrag {
                                if !editing { withAnimation(.rundumSnappy) { editing = true } }
                                dragging = card.id
                                return NSItemProvider(object: card.id.rawValue as NSString)
                            } preview: {
                                RoundedRectangle(cornerRadius: 22).fill(card.accent.opacity(0.18)).frame(width: card.width == .half ? 150 : 300, height: 120)
                                    .overlay { Label(state.copy.card(card.id), systemImage: card.id.symbol).font(.headline).foregroundStyle(card.accent) }
                            }
                            .onDrop(of: [UTType.text], delegate: DashboardCardDropDelegate(target: card.id, dragging: $dragging, cards: $state.configuration.cards) { state.changed(cloud: cloud) })
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
    private func resize(_ card: DashboardCard, to width: CardWidth) {
        guard let index = state.configuration.cards.firstIndex(where: { $0.id == card.id }), state.configuration.cards[index].width != width else { return }
        withAnimation(.rundum) { state.configuration.cards[index].width = width }
        state.changed(cloud: cloud)
    }
    private func remove(_ card: DashboardCard) {
        withAnimation(.rundum) { state.configuration.cards.removeAll { $0.id == card.id } }
        state.changed(cloud: cloud)
    }
}

struct HalfCardLayoutKey: LayoutValueKey { static let defaultValue = false }

struct CardEditMenu: View {
    let card: DashboardCard
    let resize: (CardWidth) -> Void
    let customize: () -> Void
    let remove: () -> Void
    @EnvironmentObject var state: AppState
    var body: some View {
        Menu {
            Section(state.copy("Kartengröße", "Taille de la carte", "Card size")) {
                Button { resize(.half) } label: { Label(state.copy("Klein", "Petite", "Small"), systemImage: card.width == .half ? "checkmark" : "square") }
                Button { resize(.full) } label: { Label(state.copy("Breit", "Large", "Wide"), systemImage: card.width == .full ? "checkmark" : "rectangle") }
            }
            Button(action: customize) { Label(state.copy("Gestalten", "Personnaliser", "Customize"), systemImage: "paintpalette") }
            Divider()
            Button(role: .destructive, action: remove) { Label(state.copy("Entfernen", "Supprimer", "Remove"), systemImage: "trash") }
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption.bold()).foregroundStyle(card.accent)
                .frame(width: 30, height: 30).background(.regularMaterial, in: Circle()).shadow(color: .black.opacity(0.14), radius: 4, y: 2)
        }.accessibilityLabel(state.copy("Kartengröße und Optionen", "Taille et options de la carte", "Card size and options"))
            .accessibilityIdentifier("resize-card-" + card.id.rawValue)
    }
}

struct DashboardCardDropDelegate: DropDelegate {
    let target: CardKind
    @Binding var dragging: CardKind?
    @Binding var cards: [DashboardCard]
    let changed: () -> Void
    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target,
              let from = cards.firstIndex(where: { $0.id == dragging }),
              let to = cards.firstIndex(where: { $0.id == target }) else { return }
        withAnimation(.rundumSnappy) { cards.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to) }
    }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { dragging = nil; changed(); return true }
    func dropExited(info: DropInfo) { }
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
            frames.append(.init(x: 0, y: y, width: cellWidth, height: paired ? height : firstHeight))
            if paired { frames.append(.init(x: cellWidth + gap, y: y, width: cellWidth, height: height)) }
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
