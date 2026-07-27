import SwiftUI

/// The hero ring: today's steps against the daily goal.
///
/// Layered rather than a single stroke — a faint track, the gradient arc, a
/// glowing head at the leading edge, and a second gold lap once the goal is
/// beaten. Going past 100% is the best moment of the day, so it gets its own
/// visual state instead of a bar that quietly stops moving.
struct GoalRing: View {
    let steps: Int
    let goal: Int
    var lineWidth: CGFloat = 24
    var diameter: CGFloat = 250
    /// Optional caption under the count, e.g. "4,300 to go".
    var caption: String?

    @State private var animatedProgress: Double = 0

    private var rawProgress: Double {
        guard goal > 0 else { return 0 }
        return Double(steps) / Double(goal)
    }

    private var firstLap: Double { min(rawProgress, 1) }
    private var secondLap: Double { min(max(rawProgress - 1, 0), 1) }
    private var goalReached: Bool { goal > 0 && steps >= goal }

    var body: some View {
        ZStack {
            track
            progressArc
            if secondLap > 0 { overflowArc }
            head
            centerLabel
        }
        .frame(width: diameter, height: diameter)
        .onAppear { animate(to: firstLap) }
        .onChange(of: firstLap) { _, newValue in animate(to: newValue) }
    }

    // MARK: Layers

    private var track: some View {
        Circle()
            .stroke(Color.primary.opacity(0.07), lineWidth: lineWidth)
    }

    private var progressArc: some View {
        Circle()
            .trim(from: 0, to: animatedProgress)
            .stroke(
                goalReached ? Theme.goalMetGradient : Theme.ringGradient,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .shadow(color: (goalReached ? Theme.mint : Theme.brand).opacity(0.35), radius: 12)
    }

    /// The victory lap — gold, thinner, sitting just inside the main ring.
    private var overflowArc: some View {
        Circle()
            .trim(from: 0, to: secondLap)
            .stroke(
                Theme.gold,
                style: StrokeStyle(lineWidth: lineWidth * 0.34, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .padding(lineWidth * 0.72)
            .shadow(color: Theme.gold.opacity(0.5), radius: 8)
    }

    /// A bright dot riding the end of the arc, so progress reads at a glance.
    private var head: some View {
        Circle()
            .fill(.white)
            .frame(width: lineWidth * 0.42, height: lineWidth * 0.42)
            .shadow(color: .black.opacity(0.25), radius: 3)
            .offset(y: -(diameter - lineWidth) / 2)
            .rotationEffect(.degrees(360 * animatedProgress))
            .opacity(animatedProgress > 0.01 ? 1 : 0)
    }

    private var centerLabel: some View {
        VStack(spacing: 2) {
            Text(steps, format: .number)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("steps")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if let caption {
                Text(caption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(goalReached ? Theme.mint : .secondary)
                    .padding(.top, 6)
                    .multilineTextAlignment(.center)
            } else if goal > 0 {
                Text(goalReached ? "Goal smashed" : "of \(goal.grouped)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(goalReached ? Theme.mint : .secondary)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, lineWidth * 1.6)
    }

    private func animate(to value: Double) {
        withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) {
            animatedProgress = value
        }
    }
}

/// Compact ring used in lists and cards where the hero ring won't fit.
struct MiniRing: View {
    let progress: Double
    var tint: Color = Theme.brand
    var size: CGFloat = 34
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        AuroraBackground()
        VStack(spacing: 30) {
            GoalRing(steps: 6_200, goal: 10_000, caption: "3,800 to go")
            GoalRing(steps: 14_800, goal: 10_000, diameter: 190)
        }
    }
}
