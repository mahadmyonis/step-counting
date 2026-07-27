import SwiftUI
import UIKit

/// Design tokens for the whole app.
///
/// Everything visual — colour, depth, motion — resolves through here so screens
/// stay consistent and a palette change is a one-file edit.
enum Theme {

    // MARK: Brand palette

    static let brand = Color(red: 0.35, green: 0.40, blue: 0.98)
    static let violet = Color(red: 0.63, green: 0.36, blue: 1.00)
    static let sky = Color(red: 0.20, green: 0.76, blue: 0.99)
    static let mint = Color(red: 0.16, green: 0.83, blue: 0.60)
    static let flame = Color(red: 1.00, green: 0.55, blue: 0.20)
    static let coral = Color(red: 1.00, green: 0.38, blue: 0.42)
    static let gold = Color(red: 1.00, green: 0.78, blue: 0.24)

    /// Tints assigned to people and crews. Index into this, never hard-code.
    static let accents: [Color] = [brand, violet, sky, mint, flame, coral, gold]

    static func accent(_ index: Int) -> Color {
        accents[abs(index) % accents.count]
    }

    // MARK: Gradients

    /// Sweeps the goal ring through the full brand spectrum as progress climbs.
    static let ringGradient = AngularGradient(
        gradient: Gradient(colors: [brand, violet, coral, flame, gold, mint, sky, brand]),
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
        colors: [gold, flame, coral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func softGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.85), color.opacity(0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: Metrics

    static let cardRadius: CGFloat = 22
    static let tightRadius: CGFloat = 14
    static let cardPadding: CGFloat = 16
    static let screenPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 22

    // MARK: Motion

    static let springy = Animation.spring(response: 0.42, dampingFraction: 0.72)
    static let gentle = Animation.easeInOut(duration: 0.55)
}

// MARK: - Glass card

/// Frosted card surface used for nearly every block of content.
///
/// Built from `Material` + a hairline gradient stroke rather than the iOS 26
/// glass APIs, so it renders identically on the iOS 17 deployment target.
struct GlassCard: ViewModifier {
    var radius: CGFloat = Theme.cardRadius
    var padding: CGFloat? = Theme.cardPadding
    var tint: Color = .clear

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tint.opacity(0.14))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func glassCard(
        radius: CGFloat = Theme.cardRadius,
        padding: CGFloat? = Theme.cardPadding,
        tint: Color = .clear
    ) -> some View {
        modifier(GlassCard(radius: radius, padding: padding, tint: tint))
    }
}

// MARK: - Background

/// Slowly drifting colour blobs behind a blurred backdrop.
///
/// Gives every screen depth without competing with content. The drift is a
/// single repeating animation, so it costs one animated transform per blob.
struct AuroraBackground: View {
    var tint: Color = Theme.brand
    var secondary: Color = Theme.violet

    @State private var drift = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    blob(tint, size: geo.size.width * 1.05)
                        .offset(
                            x: drift ? -geo.size.width * 0.28 : -geo.size.width * 0.14,
                            y: drift ? -geo.size.height * 0.32 : -geo.size.height * 0.22
                        )

                    blob(secondary, size: geo.size.width * 0.95)
                        .offset(
                            x: drift ? geo.size.width * 0.32 : geo.size.width * 0.18,
                            y: drift ? -geo.size.height * 0.06 : geo.size.height * 0.04
                        )

                    blob(Theme.sky, size: geo.size.width * 0.8)
                        .offset(
                            x: drift ? -geo.size.width * 0.10 : geo.size.width * 0.06,
                            y: drift ? geo.size.height * 0.34 : geo.size.height * 0.42
                        )
                }
                .blur(radius: 70)
            }
            .ignoresSafeArea()
            .opacity(0.55)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.75), color.opacity(0.0)],
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing
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
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Theme.springy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// Small pill used for streaks, ranks, and status chips.
struct Pill: View {
    let text: String
    var systemImage: String?
    var tint: Color = Theme.brand

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.15), in: Capsule())
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
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Theme.softGradient(tint))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
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
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
}
