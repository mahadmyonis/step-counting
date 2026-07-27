import SwiftUI

/// Canvas-drawn confetti burst for goal hits, badge unlocks, and challenge wins.
///
/// Drawn in a single `Canvas` pass rather than as N animated views: 90 pieces
/// cost one draw call per frame instead of 90 layout passes, so it stays smooth
/// on top of a live-updating dashboard.
struct ConfettiView: View {
    var isActive: Bool
    var duration: Double = 2.6

    @State private var startedAt: Date?

    private let pieces: [Piece] = Piece.makeBurst(count: 90, seed: 0xC0FFEE)

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: startedAt == nil)) { timeline in
                Canvas { context, size in
                    guard let startedAt else { return }
                    let elapsed = timeline.date.timeIntervalSince(startedAt)
                    guard elapsed < duration else { return }

                    for piece in pieces {
                        draw(piece, elapsed: elapsed, in: size, context: context)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newValue in
            startedAt = newValue ? Date() : nil
        }
        .onAppear {
            if isActive { startedAt = Date() }
        }
    }

    private func draw(_ piece: Piece, elapsed: Double, in size: CGSize, context: GraphicsContext) {
        let t = elapsed - piece.delay
        guard t > 0 else { return }

        // Launch up, then fall under gravity — a lob rather than a straight drop.
        let x = size.width * piece.originX + piece.drift * t * 60
        let y = size.height * 0.32 - piece.launch * t * 130 + 190 * t * t
        guard y < size.height + 40 else { return }

        let fade = max(0, 1 - (t / (duration - piece.delay)))

        var layer = context
        layer.translateBy(x: x, y: y)
        layer.rotate(by: .degrees(piece.spin * t * 260))
        layer.opacity = fade

        let rect = CGRect(
            x: -piece.width / 2,
            y: -piece.height / 2,
            width: piece.width,
            height: piece.height
        )
        layer.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(piece.color))
    }

    struct Piece {
        let originX: Double
        let drift: Double
        let launch: Double
        let spin: Double
        let delay: Double
        let width: Double
        let height: Double
        let color: Color

        static func makeBurst(count: Int, seed: UInt64) -> [Piece] {
            var rng = SeededGenerator(seed: seed)
            let palette: [Color] = [
                Theme.brand, Theme.violet, Theme.sky,
                Theme.mint, Theme.flame, Theme.gold, Theme.coral
            ]

            return (0..<count).map { index in
                Piece(
                    originX: Double.random(in: 0.08...0.92, using: &rng),
                    drift: Double.random(in: -1.4...1.4, using: &rng),
                    launch: Double.random(in: 0.7...2.1, using: &rng),
                    spin: Double.random(in: -1.6...1.6, using: &rng),
                    delay: Double.random(in: 0...0.45, using: &rng),
                    width: Double.random(in: 5...10, using: &rng),
                    height: Double.random(in: 8...15, using: &rng),
                    color: palette[index % palette.count]
                )
            }
        }
    }
}

/// A celebration worth interrupting the user for.
///
/// Only the highest-value moments produce one — hitting the goal, unlocking a
/// badge, winning a challenge — because a celebration that fires constantly
/// stops reading as a reward.
struct Celebration: Identifiable, Equatable {
    let id = UUID()
    let emoji: String
    let title: String
    let message: String
    var shareHeadline: String?
}

/// Full-screen celebration overlay with confetti and an optional share hook.
struct CelebrationOverlay: View {
    let celebration: Celebration
    var onShare: (() -> Void)?
    var onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 16) {
                Text(celebration.emoji)
                    .font(.system(size: 68))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -25))

                Text(celebration.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(celebration.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    if let onShare {
                        Button {
                            onShare()
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.brand)
                    }

                    Button("Nice") { onDismiss() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: onShare == nil ? .infinity : nil)
                }
                .padding(.top, 4)
            }
            .padding(26)
            .frame(maxWidth: 330)
            .glassCard(radius: 28, padding: 0)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)

            ConfettiView(isActive: appeared)
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(Theme.springy) { appeared = true }
            Haptics.success()
        }
    }
}
