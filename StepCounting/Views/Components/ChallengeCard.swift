import SwiftUI

/// Summary card for a challenge in a list.
struct ChallengeCard: View {
    let challenge: Challenge
    let progress: Double
    var yourStanding: Standing?
    var pace: String?
    var participantCount: Int
    var useMetric: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(challenge.emoji)
                    .font(.system(size: 30))
                    .frame(width: 46, height: 46)
                    .background(challenge.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(challenge.title)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Label(challenge.format.title, systemImage: challenge.format.symbol)
                        Text("·")
                        Text("\(participantCount) walking")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(challenge.status())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(challenge.hasEnded() ? .secondary : challenge.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        (challenge.hasEnded() ? Color.secondary : challenge.tint).opacity(0.14),
                        in: Capsule()
                    )
                    .fixedSize()
            }

            VStack(alignment: .leading, spacing: 7) {
                ProgressBarRow(progress: progress, tint: challenge.tint)

                HStack(spacing: 8) {
                    if let yourStanding {
                        Text(rankText(yourStanding))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(challenge.tint)
                    }

                    if challenge.target > 0 {
                        Text(targetText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if let pace {
                        Text(pace)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .glassCard(tint: challenge.tint)
    }

    private func rankText(_ standing: Standing) -> String {
        if challenge.format.isCooperative {
            return "You: \(challenge.metric.format(standing.value, metric: useMetric))"
        }
        return "\(standing.medal ?? "") \(ordinal(standing.rank)) place"
            .trimmingCharacters(in: .whitespaces)
    }

    private var targetText: String {
        "· target \(challenge.metric.format(challenge.target, metric: useMetric))"
    }

    private func ordinal(_ value: Int) -> String {
        let suffix: String
        switch (value % 10, value % 100) {
        case (_, 11), (_, 12), (_, 13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(value)\(suffix)"
    }
}

/// Horizontal journey bar for route-backed challenges.
///
/// A percentage is abstract; "you've just passed León and Cruz de Ferro is next"
/// is a reason to keep walking.
struct RouteProgressView: View {
    let route: VirtualRoute
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(route.emoji)
                VStack(alignment: .leading, spacing: 1) {
                    Text(route.name)
                        .font(.subheadline.weight(.semibold))
                    Text(route.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("\(Int(progress * 100))%")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }

            track

            HStack(alignment: .top) {
                if let last = route.lastReached(at: progress) {
                    landmarkLabel("Last", last, tint: Theme.mint)
                }
                Spacer(minLength: 12)
                if let next = route.nextLandmark(after: progress) {
                    landmarkLabel("Next up", next, tint: Theme.brand, alignment: .trailing)
                }
            }
        }
    }

    private var track: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 10)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.brand, Theme.violet, Theme.mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(10, geo.size.width * clamped), height: 10)

                ForEach(route.landmarks) { landmark in
                    Circle()
                        .fill(landmark.fraction <= clamped ? Theme.mint : Color.primary.opacity(0.22))
                        .frame(width: 6, height: 6)
                        .offset(x: geo.size.width * landmark.fraction - 3)
                }

                Text("🚶")
                    .font(.system(size: 15))
                    .offset(x: max(0, geo.size.width * clamped - 8), y: -14)
            }
            .frame(height: 10)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 26)
    }

    private var clamped: Double { min(max(progress, 0), 1) }

    private func landmarkLabel(
        _ caption: String,
        _ landmark: VirtualRoute.Landmark,
        tint: Color,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(caption.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text("\(landmark.emoji) \(landmark.name)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
    }
}

#Preview {
    ZStack {
        AuroraBackground()
        ScrollView {
            VStack(spacing: 16) {
                ChallengeCard(
                    challenge: ChallengeTemplate.catalog[1].makeChallenge(
                        crewID: nil, participantIDs: [], createdByID: UUID()
                    ),
                    progress: 0.42,
                    yourStanding: Standing(id: UUID(), name: "You", emoji: "⚡️", accentIndex: 1,
                                           isYou: true, value: 42_000, rank: 2, progress: 0.42),
                    pace: "3.2k ahead of pace",
                    participantCount: 5
                )

                if let camino = VirtualRoute.catalog["camino"] {
                    RouteProgressView(route: camino, progress: 0.58)
                        .glassCard()
                }
            }
            .padding()
        }
    }
}
