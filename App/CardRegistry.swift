import SwiftUI

/// Register a card provider here; storage and dashboard rendering do not change.
/// String IDs preserve configuration from newer app versions instead of losing the whole layout.
struct CardPlugin: Identifiable {
    let id: CardKind
    let render: (DashboardCard, [CalendarItem]) -> AnyView
}
enum CardRegistry {
    static let plugins: [CardPlugin] = [CardKind.calendar, .steps, .sleep, .heart, .workouts].map { kind in
        CardPlugin(id: kind, render: { card, events in AnyView(DashboardCardView(card: card, events: events)) })
    }
    static var kinds: [CardKind] { plugins.map(\.id) }
    static func render(card: DashboardCard, events: [CalendarItem]) -> AnyView {
        plugins.first { $0.id == card.id }?.render(card, events) ?? AnyView(EmptyView())
    }
}
