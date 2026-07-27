import SwiftUI

/// One entry in the crew activity feed, with a cheer button.
///
/// Cheering is one tap and costs nothing, which is exactly why people do it —
/// and being cheered is what makes someone walk again tomorrow.
struct FeedRow: View {
    let event: FeedEvent
    var onCheer: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(emoji: event.actorEmoji, accentIndex: event.accentIndex, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: event.kind.symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(event.kind.tint)

                    Text(event.actorName)
                        .font(.subheadline.weight(.semibold))
                        + Text(" \(event.message)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .lineLimit(2)

                Text(event.date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)

            cheerButton
        }
        .padding(.vertical, 8)
    }

    private var cheerButton: some View {
        Button(action: onCheer) {
            HStack(spacing: 4) {
                Image(systemName: event.youCheered ? "hands.clap.fill" : "hands.clap")
                    .font(.caption.weight(.bold))
                if event.cheers > 0 {
                    Text("\(event.cheers)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(event.youCheered ? Theme.gold : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                (event.youCheered ? Theme.gold : Color.secondary).opacity(0.14),
                in: Capsule()
            )
        }
        .buttonStyle(.pressable)
        .animation(Theme.springy, value: event.youCheered)
    }
}

#Preview {
    ZStack {
        AuroraBackground()
        VStack {
            FeedRow(
                event: FeedEvent(
                    id: "1", date: Date().addingTimeInterval(-3_600), actorID: UUID(),
                    actorName: "Kiran", actorEmoji: "🐆", accentIndex: 2,
                    kind: .personalBest, message: "smashed 21,480 steps", cheers: 3
                ),
                onCheer: {}
            )
            FeedRow(
                event: FeedEvent(
                    id: "2", date: Date().addingTimeInterval(-7_200), actorID: UUID(),
                    actorName: "You", actorEmoji: "⚡️", accentIndex: 1,
                    kind: .badgeUnlocked, message: "earned Week Strong", cheers: 1, youCheered: true
                ),
                onCheer: {}
            )
        }
        .glassCard()
        .padding()
    }
}
