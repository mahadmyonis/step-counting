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
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            header
            ProgressBarRow(progress: progress, tint: challenge.tint)
            footer
        }
        .card(tint: challenge.tint)
        .accessibilityElement(children: .combine)
    }

    // MARK: Rows

    private var header: some View {
        HStack(alignment: .center, spacing: Theme.Space.md) {
            Text(challenge.emoji)
                .font(.system(size: 28))
                .frame(width: 46, height: 46)
                .background(
                    challenge.tint.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.chip + 2, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                // Short labels and a fixed size, so these never become
                // "Race to…" on a narrow phone.
                HStack(spacing: Theme.Space.sm) {
                    label(challenge.format.symbol, challenge.format.shortTitle)
                    label("person.2.fill", "\(participantCount)")
                }
            }

            Spacer(minLength: Theme.Space.xs)

            Text(challenge.status())
                .font(.caption2.weight(.bold))
                .foregroundStyle(challenge.hasEnded() ? .secondary : challenge.tint)
                .padding(.horizontal, Theme.Space.sm)
                .padding(.vertical, 5)
                .background(
                    (challenge.hasEnded() ? Color.secondary : challenge.tint).opacity(0.13),
                    in: Capsule()
                )
                .fixedSize()
        }
    }

    /// Rank on the left, pace on the right — each on its own line's worth of
    /// room rather than three fragments competing for one row.
    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
            if let yourStanding {
                Text(rankText(yourStanding))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(challenge.tint)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Space.xs)

            if let pace {
                Text(pace)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else if challenge.target > 0 {
                Text(challenge.metric.format(challenge.target, metric: useMetric))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func label(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .fixedSize()
    }

    private func rankText(_ standing: Standing) -> String {
        if challenge.format.isCooperative {
            return challenge.metric.format(standing.value, metric: useMetric)
        }
        return "\(standing.medal ?? "") \(ordinal(standing.rank))"
            .trimmingCharacters(in: .whitespaces)
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
        ScreenBackground()
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
                        .card()
                }
            }
            .padding()
        }
    }
}
