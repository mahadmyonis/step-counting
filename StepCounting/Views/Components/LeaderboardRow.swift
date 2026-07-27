import SwiftUI

/// One line of a standings table.
///
/// Your own row is tinted and outlined so it's findable without reading — on a
/// six-person board, "where am I" should take no effort at all.
struct StandingRow: View {
    let standing: Standing
    let metric: ChallengeMetric
    var useMetric: Bool = true
    /// Hidden for cooperative challenges, where ranking people is beside the point.
    var showsRank: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            if showsRank {
                rankBadge
                    .frame(width: 28)
            }

            AvatarView(
                emoji: standing.emoji,
                accentIndex: standing.accentIndex,
                size: 36,
                isYou: standing.isYou
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(standing.name)
                    .font(.subheadline.weight(standing.isYou ? .bold : .medium))
                    .lineLimit(1)

                ProgressBarRow(progress: standing.progress, tint: standing.tint, height: 6)
            }

            Text(metric.format(standing.value, metric: useMetric))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(standing.isYou ? .primary : .secondary)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(standing.isYou ? standing.tint.opacity(0.12) : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(standing.isYou ? standing.tint.opacity(0.45) : .clear, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var rankBadge: some View {
        if let medal = standing.medal {
            Text(medal)
                .font(.title3)
        } else {
            Text("\(standing.rank)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

/// Compact crew standings for today, shown on the dashboard.
///
/// Seeing that you're two places off the top with an hour of daylight left is
/// the whole point of walking with other people.
struct TodayBoardRow: View {
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.medal ?? "\(entry.rank)")
                .font(entry.medal == nil ? .caption.weight(.bold) : .body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 24)

            AvatarView(emoji: entry.emoji, accentIndex: entry.accentIndex, size: 32, isYou: entry.isYou)

            Text(entry.name)
                .font(.subheadline.weight(entry.isYou ? .bold : .regular))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(entry.value.grouped)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(entry.isYou ? .primary : .secondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        VStack(spacing: 4) {
            StandingRow(
                standing: Standing(id: UUID(), name: "Kiran", emoji: "🐆", accentIndex: 2,
                                   isYou: false, value: 84_200, rank: 1, progress: 0.84),
                metric: .steps
            )
            StandingRow(
                standing: Standing(id: UUID(), name: "You", emoji: "⚡️", accentIndex: 1,
                                   isYou: true, value: 79_100, rank: 2, progress: 0.79),
                metric: .steps
            )
        }
        .padding()
    }
}
