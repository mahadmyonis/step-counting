import SwiftUI
import UIKit

/// Design tokens for the whole app.
///
/// Everything visual — colour, depth, rhythm, motion — resolves through here so
/// screens stay consistent and a palette change is a one-file edit.
enum Theme {

    // MARK: Brand palette

    static let brand = Color(red: 0.35, green: 0.38, blue: 0.96)
    static let violet = Color(red: 0.58, green: 0.36, blue: 0.98)
    static let sky = Color(red: 0.16, green: 0.66, blue: 0.96)
    static let mint = Color(red: 0.09, green: 0.72, blue: 0.51)
    static let flame = Color(red: 0.98, green: 0.49, blue: 0.16)
    static let coral = Color(red: 0.96, green: 0.32, blue: 0.42)
    static let gold = Color(red: 0.95, green: 0.71, blue: 0.15)

    /// Tints assigned to people and crews. Index into this, never hard-code.
    static let accents: [Color] = [brand, violet, sky, mint, flame, coral, gold]

    static func accent(_ index: Int) -> Color {
        accents[abs(index) % accents.count]
    }

    // MARK: Surfaces

    /// The page behind everything.
    static var canvas: Color { Color(uiColor: .systemGroupedBackground) }

    /// Cards and rows that sit on the canvas.
    ///
    /// A solid elevated surface rather than a translucent one: frosted glass over
    /// a coloured background looked good in isolation but left every card at a
    /// contrast ratio that made text hard to read on a real screen.
    static var surface: Color { Color(uiColor: .secondarySystemGroupedBackground) }

    /// One level further up — chips and wells sitting inside a card.
    static var surfaceRaised: Color { Color(uiColor: .tertiarySystemGroupedBackground) }

    static var hairline: Color { Color.primary.opacity(0.07) }

    // MARK: Gradients

    /// The ring sweep.
    ///
    /// Three brand hues rather than a full spectrum — a rainbow looked busy and
    /// implied a meaning the colours don't carry.
    static let ringGradient = AngularGradient(
        gradient: Gradient(stops: [
            .init(color: brand, location: 0.00),
            .init(color: violet, location: 0.35),
            .init(color: coral, location: 0.68),
            .init(color: flame, location: 0.88),
            .init(color: brand, location: 1.00)
        ]),
        center: .center,
        startAngle: .degrees(0),
        endAngle: .degrees(360)
    )

    static let goalMetGradient = AngularGradient(
        gradient: Gradient(colors: [mint, sky, mint]),
        center: .center,
        startAngle: .degrees(0),
        endAngle: .degrees(360)
    )

    static let streakGradient = LinearGradient(
        colors: [gold, flame],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func fill(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: Rhythm

    /// One spacing scale. Nothing should use a number that isn't on it.
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    enum Radius {
        static let chip: CGFloat = 10
        static let tight: CGFloat = 14
        static let card: CGFloat = 20
        static let hero: CGFloat = 28
    }

    static let screenPadding: CGFloat = Space.lg
    static let sectionSpacing: CGFloat = Space.xxl
    static let cardPadding: CGFloat = Space.lg

    // Legacy aliases so older call sites keep compiling.
    static let cardRadius = Radius.card
    static let tightRadius = Radius.tight

    // MARK: Motion

    static let springy = Animation.spring(response: 0.38, dampingFraction: 0.78)
    static let gentle = Animation.easeInOut(duration: 0.45)
}

// MARK: - Card surface

/// The standard content surface: solid fill, hairline border, soft lift.
struct CardSurface: ViewModifier {
    var radius: CGFloat = Theme.Radius.card
    var padding: CGFloat? = Theme.cardPadding
    /// Washes the card with a colour when it belongs to a crew or challenge.
    var tint: Color = .clear

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tint.opacity(0.07))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(tint == .clear ? Theme.hairline : tint.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func card(
        radius: CGFloat = Theme.Radius.card,
        padding: CGFloat? = Theme.cardPadding,
        tint: Color = .clear
    ) -> some View {
        modifier(CardSurface(radius: radius, padding: padding, tint: tint))
    }
}

// MARK: - Background

/// The page backdrop: a neutral canvas with one soft accent glow.
///
/// Deliberately quiet. An earlier version layered three animated colour blobs,
/// which looked striking in isolation and turned every screen into a purple haze
/// that content had to fight through.
struct ScreenBackground: View {
    var tint: Color = Theme.brand
    var secondary: Color = Theme.violet

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .top) {
            Theme.canvas

            GeometryReader { geo in
                ZStack {
                    glow(tint, size: geo.size.width * 1.3)
                        .offset(x: -geo.size.width * 0.25, y: -geo.size.height * 0.24)

                    glow(secondary, size: geo.size.width * 0.9)
                        .offset(x: geo.size.width * 0.34, y: -geo.size.height * 0.05)
                }
                .blur(radius: 60)
                .opacity(scheme == .dark ? 0.32 : 0.20)
            }
        }
        .ignoresSafeArea()
    }

    private func glow(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
    }
}

// MARK: - Building blocks

/// Section title with an optional trailing action, used down every screen.
struct SectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Theme.Space.sm)
            trailing
                .font(.subheadline.weight(.semibold))
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Button style that dips and softens on press — used for every tappable card.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.975

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Theme.springy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// The app's primary call to action.
struct ProminentButtonStyle: ButtonStyle {
    var tint: Color = Theme.brand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.fill(tint), in: RoundedRectangle(cornerRadius: Theme.Radius.tight, style: .continuous))
            .shadow(color: tint.opacity(0.3), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Theme.springy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ProminentButtonStyle {
    static var prominent: ProminentButtonStyle { ProminentButtonStyle() }
    static func prominent(_ tint: Color) -> ProminentButtonStyle { ProminentButtonStyle(tint: tint) }
}

/// Small pill used for streaks, ranks, and status chips.
struct Pill: View {
    let text: String
    var systemImage: String?
    var tint: Color = Theme.brand

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Theme.Space.sm + 2)
        .padding(.vertical, 5)
        .background(tint.opacity(0.13), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// Centered placeholder for empty and permission states.
struct InfoState: View {
    let systemImage: String
    let title: String
    let message: String
    var tint: Color = Theme.brand
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 68, height: 68)
                .background(tint.opacity(0.12), in: Circle())

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.prominent(tint))
                    .padding(.top, Theme.Space.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.sm)
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func celebrate() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}
