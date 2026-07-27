import SwiftUI

/// The badge case.
///
/// Locked badges stay visible with their progress showing — a badge you can see
/// yourself approaching is a goal; a badge hidden until you earn it is a
/// surprise, and surprises don't motivate anyone to walk.
struct AchievementsView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var store: AppStore

    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000

    @State private var selected: Achievement?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            AuroraBackground(tint: Theme.gold, secondary: Theme.violet)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    summary

                    ForEach(Achievement.Tier.allCases) { tier in
                        tierSection(tier)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { badge in
            BadgeDetailSheet(
                badge: badge,
                unlockedAt: store.unlockedBadges[badge.id],
                progress: badge.requirement.progress(in: context),
                profile: store.profile
            )
            .presentationDetents([.height(420)])
        }
    }

    // MARK: Sections

    private var summary: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Theme.gold.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(store.unlockedBadges.count) / Double(Achievement.catalog.count))
                    .stroke(Theme.gold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(store.unlockedBadges.count)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(store.unlockedBadges.count) of \(Achievement.catalog.count) earned")
                    .font(.headline)
                if let next = nextClosest {
                    Text("Closest: \(next.title) — \(Int(next.requirement.progress(in: context) * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .glassCard(tint: Theme.gold)
    }

    private func tierSection(_ tier: Achievement.Tier) -> some View {
        let badges = Achievement.catalog.filter { $0.tier == tier }
        let earned = badges.filter { store.unlockedBadges[$0.id] != nil }.count

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: tier.title, subtitle: "\(earned)/\(badges.count)") {
                Circle()
                    .fill(tier.tint)
                    .frame(width: 10, height: 10)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(badges) { badge in
                    Button {
                        selected = badge
                        Haptics.tap()
                    } label: {
                        BadgeTile(
                            badge: badge,
                            isUnlocked: store.unlockedBadges[badge.id] != nil,
                            progress: badge.requirement.progress(in: context)
                        )
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    // MARK: Derived

    private var context: AchievementContext {
        AchievementContext(
            bestDaySteps: max(health.history.bestDay?.steps ?? 0, health.today.steps),
            lifetimeSteps: max(health.lifetime.steps, health.history.totalSteps),
            lifetimeDistanceMeters: max(health.lifetime.distanceMeters, health.history.totalDistanceMeters),
            lifetimeFlights: health.lifetime.flights,
            longestStreak: store.streak.longest,
            goalDays: store.streak.totalGoalDays,
            challengesWon: store.profile.challengesWon,
            crewCount: store.crews.count,
            earliestGoalHour: health.hourGoalReached(goal: dailyGoal),
            hourly: health.hourlyToday
        )
    }

    /// The unearned badge closest to completion — the one worth pointing at.
    private var nextClosest: Achievement? {
        Achievement.catalog
            .filter { store.unlockedBadges[$0.id] == nil }
            .max { $0.requirement.progress(in: context) < $1.requirement.progress(in: context) }
    }
}

// MARK: - Tile

struct BadgeTile: View {
    let badge: Achievement
    let isUnlocked: Bool
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? badge.tier.tint.opacity(0.22) : Color.primary.opacity(0.06))
                    .frame(width: 54, height: 54)

                if !isUnlocked, progress > 0 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(badge.tier.tint.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 54, height: 54)
                }

                Image(systemName: badge.symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(isUnlocked ? badge.tier.tint : Color.secondary.opacity(0.5))
            }

            Text(badge.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 26, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: Theme.tightRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(isUnlocked ? 1 : 0.55)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.tightRadius, style: .continuous)
                .strokeBorder(isUnlocked ? badge.tier.tint.opacity(0.4) : .clear, lineWidth: 1)
        }
    }
}

// MARK: - Detail

struct BadgeDetailSheet: View {
    let badge: Achievement
    let unlockedAt: Date?
    let progress: Double
    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(badge.tier.tint.opacity(unlockedAt != nil ? 0.24 : 0.1))
                    .frame(width: 96, height: 96)
                Image(systemName: badge.symbol)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(unlockedAt != nil ? badge.tier.tint : Color.secondary)
            }
            .padding(.top, 28)

            VStack(spacing: 5) {
                Text(badge.title)
                    .font(.title2.weight(.bold))
                Text(badge.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                Pill(text: badge.tier.title, systemImage: "rosette", tint: badge.tier.tint)
                Pill(text: "\(badge.tier.xp) XP", systemImage: "sparkles", tint: Theme.violet)
            }

            if let unlockedAt {
                Text("Earned \(unlockedAt.formatted(.dateTime.month(.wide).day().year()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ShareCardButton(
                    card: ShareCard(
                        headline: badge.title,
                        subheadline: badge.detail,
                        profile: profile,
                        badgeTitle: "\(badge.tier.title) badge",
                        accent: badge.tier.tint
                    ),
                    label: "Share badge"
                )
                .buttonStyle(.borderedProminent)
                .tint(badge.tier.tint)
            } else {
                VStack(spacing: 6) {
                    ProgressBarRow(progress: progress, tint: badge.tier.tint, height: 8)
                    Text("\(Int(progress * 100))% there")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

#Preview {
    NavigationStack {
        AchievementsView()
            .environmentObject(HealthKitManager.preview())
            .environmentObject(AppStore.preview())
    }
}
