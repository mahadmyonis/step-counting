import SwiftUI

/// The streak card — the single most-looked-at thing on the dashboard after the
/// ring, and the reason a lot of people open the app at all.
///
/// It always answers three questions: how long is the run, is it safe tonight,
/// and — if it isn't — exactly what it would take to keep it.
struct StreakCard: View {
    let streak: StreakState
    let status: StreakStatus
    var onUseFreeze: (() -> Void)?

    @State private var flameGlow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let message = statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if case .rescuable = status, let onUseFreeze {
                Button(action: onUseFreeze) {
                    Label("Use a streak freeze", systemImage: "snowflake")
                }
                .buttonStyle(.prominent(Theme.sky))
            }

            footer
        }
        .card(tint: streak.current > 0 ? Theme.flame : .clear)
        .onAppear {
            guard streak.current > 0 else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                flameGlow = true
            }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.streakGradient)
                    .frame(width: 52, height: 52)
                    .opacity(streak.current > 0 ? 1 : 0.25)
                    .shadow(
                        color: Theme.flame.opacity(streak.current > 0 && flameGlow ? 0.55 : 0.15),
                        radius: flameGlow ? 14 : 6
                    )

                Image(systemName: streak.current > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(streak.current)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(streak.current == 1 ? "day" : "days")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Text(headline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(headlineTint)
            }

            Spacer(minLength: 0)

            if streak.freezesAvailable > 0 {
                VStack(spacing: 3) {
                    Image(systemName: "snowflake")
                        .font(.subheadline.weight(.bold))
                    Text("\(streak.freezesAvailable)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                }
                .foregroundStyle(Theme.sky)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.sky.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let next = streak.nextMilestone, let togo = streak.daysToNextMilestone {
            VStack(alignment: .leading, spacing: 6) {
                ProgressBarRow(
                    progress: Double(streak.current) / Double(max(next, 1)),
                    tint: Theme.flame,
                    height: 6
                )
                HStack {
                    Text("\(togo) day\(togo == 1 ? "" : "s") to \(next)")
                    Spacer()
                    Text("Best: \(streak.longest)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Copy

    private var headline: String {
        switch status {
        case .safe: return "Locked in for today"
        case .atRisk: return "Not safe yet"
        case .rescuable: return "Streak broken yesterday"
        case .none: return streak.longest > 0 ? "Start a new run" : "Hit your goal to start"
        }
    }

    private var headlineTint: Color {
        switch status {
        case .safe: return Theme.mint
        case .atRisk: return Theme.flame
        case .rescuable: return Theme.sky
        case .none: return .secondary
        }
    }

    private var statusMessage: String? {
        switch status {
        case .safe:
            return nil
        case .atRisk(let remaining):
            guard remaining > 0 else { return nil }
            let minutes = max(1, Int((Double(remaining) / 110).rounded()))
            return "\(remaining.grouped) steps left — roughly a \(minutes)-minute walk."
        case .rescuable(let freezes):
            return "You have \(freezes) freeze\(freezes == 1 ? "" : "s") banked. Spend one to keep the run alive."
        case .none:
            return nil
        }
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        VStack(spacing: 16) {
            StreakCard(
                streak: StreakState(current: 12, longest: 21, freezesAvailable: 2),
                status: .atRisk(stepsRemaining: 2_400)
            )
            StreakCard(
                streak: StreakState(current: 0, longest: 30, freezesAvailable: 1),
                status: .rescuable(freezesAvailable: 1),
                onUseFreeze: {}
            )
        }
        .padding()
    }
}
