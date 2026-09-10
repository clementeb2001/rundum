import SwiftUI

/// User-chosen appearance. `.system` follows the iPhone's light/dark setting.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
}

extension Animation {
    /// Calm, physical springs used across Rundum in place of fixed-duration easing.
    static let rundum = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let rundumSnappy = Animation.spring(response: 0.32, dampingFraction: 0.74)
    static let rundumRing = Animation.spring(response: 0.75, dampingFraction: 0.9)
}

extension View {
    /// Rolling digits when a value changes. `.numericText()` is available from iOS 16.
    func rollingNumber<V: Equatable>(_ value: V) -> some View {
        contentTransition(.numericText()).animation(.rundum, value: value)
    }

    /// Gentle repeating pulse for a live symbol (e.g. the heart). No-op below iOS 17.
    @ViewBuilder func pulsingSymbol(_ active: Bool) -> some View {
        if #available(iOS 17, *) {
            symbolEffect(.pulse, options: active ? .repeating : .nonRepeating, isActive: active)
        } else { self }
    }

    /// One-shot bounce whenever `value` changes (e.g. a fresh weather update). No-op below iOS 17.
    @ViewBuilder func bouncingSymbol<V: Equatable>(on value: V) -> some View {
        if #available(iOS 17, *) { symbolEffect(.bounce, value: value) } else { self }
    }

    /// Cards fade and scale slightly as they enter/leave the viewport. No-op below iOS 17.
    @ViewBuilder func cardScrollTransition() -> some View {
        if #available(iOS 17, *) {
            scrollTransition { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.45)
                    .scaleEffect(phase.isIdentity ? 1 : 0.95)
                    .blur(radius: phase.isIdentity ? 0 : 1.5)
            }
        } else { self }
    }

    @ViewBuilder func selectionHaptic<V: Equatable>(_ value: V) -> some View {
        if #available(iOS 17, *) { sensoryFeedback(.selection, trigger: value) } else { self }
    }
    @ViewBuilder func impactHaptic<V: Equatable>(_ value: V) -> some View {
        if #available(iOS 17, *) { sensoryFeedback(.impact(flexibility: .soft), trigger: value) } else { self }
    }

    /// Card grows out of its dashboard position into the detail screen. No-op below iOS 18.
    @ViewBuilder func zoomSource(_ id: some Hashable, _ namespace: Namespace.ID) -> some View {
        if #available(iOS 18, *) { matchedTransitionSource(id: id, in: namespace) } else { self }
    }
    @ViewBuilder func zoomDestination(_ id: some Hashable, _ namespace: Namespace.ID) -> some View {
        if #available(iOS 18, *) { navigationTransition(.zoom(sourceID: id, in: namespace)) } else { self }
    }

    func shimmering(_ active: Bool) -> some View { modifier(Shimmer(active: active)) }
}

/// Lightweight loading placeholder used while data is refreshing.
struct Shimmer: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -0.7
    func body(content: Content) -> some View {
        content.overlay {
            if active {
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, Color.primary.opacity(0.10), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width)
                        .offset(x: phase * geo.size.width * 2)
                        .allowsHitTesting(false)
                }
                .onAppear { withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) { phase = 0.7 } }
            }
        }
    }
}

/// Soft, drifting weather backdrop. Uses MeshGradient on iOS 18, a linear gradient otherwise.
struct WeatherMeshBackground: View {
    var body: some View {
        if #available(iOS 18, *) {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let dx = Float(sin(t * 0.35) * 0.06)
                let dy = Float(cos(t * 0.30) * 0.06)
                MeshGradient(width: 3, height: 3, points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    .init(0, 0.5), .init(0.5 + dx, 0.5 + dy), .init(1, 0.5),
                    .init(0, 1), .init(0.5, 1), .init(1, 1)
                ], colors: Self.colors)
            }
        } else {
            LinearGradient(colors: Self.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    private static let colors: [Color] = [
        Color(red: 0.75, green: 0.89, blue: 1.00), Color(red: 1.00, green: 0.85, blue: 0.55), Color(red: 0.62, green: 0.72, blue: 0.95),
        Color(red: 0.68, green: 0.83, blue: 0.98), Color(red: 0.55, green: 0.78, blue: 0.92), Color(red: 0.30, green: 0.55, blue: 0.60),
        Color(red: 0.18, green: 0.40, blue: 0.36), Color(red: 0.42, green: 0.66, blue: 0.78), Color(red: 0.20, green: 0.45, blue: 0.55)
    ]
}
