import SwiftUI

/// Your identity, progression, and lifetime totals.
struct ProfileView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var store: AppStore

    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000
    @AppStorage(SettingsKeys.useMetric) private var useMetric = true

    @State private var editing = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(tint: Theme.accent(store.profile.accentIndex), secondary: Theme.violet)

                ScrollView {
                    VStack(spacing: Theme.sectionSpacing) {
                        identityCard
                        levelCard
                        lifetimeCard
                        badgeStrip
                        links
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .refreshable { await health.refreshAll() }
            }
            .navigationTitle("You")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { editing = true }
                }
            }
            .sheet(isPresented: $editing) { EditProfileView() }
        }
    }

    // MARK: Sections

    private var identityCard: some View {
        VStack(spacing: 12) {
            AvatarView(
                emoji: store.profile.avatarEmoji,
                accentIndex: store.profile.accentIndex,
                size: 82,
                isYou: true
            )

            Text(store.profile.displayName)
                .font(.title2.weight(.bold))

            Text("Walking since \(store.profile.joinedAt.formatted(.dateTime.month(.wide).year()))")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Pill(text: "\(store.streak.current)-day streak", systemImage: "flame.fill", tint: Theme.flame)
                Pill(text: "\(store.profile.challengesWon) wins", systemImage: "trophy.fill", tint: Theme.gold)
            }

            if let code = store.shareableInviteCode {
                ShareLink(item: inviteMessage(code: code)) {
                    Label("Invite code: \(code)", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            Theme.accent(store.profile.accentIndex).opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard(tint: Theme.accent(store.profile.accentIndex))
    }

    /// Levels never go down, which is the point — they're the counterweight to a
    /// streak that can vanish overnight.
    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Level \(store.level.index)")
                        .font(.title3.weight(.bold))
                    Text(store.level.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.violet)
                }
                Spacer()
                Text("\(store.profile.xp.grouped) XP")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            ProgressBarRow(
                progress: store.level.progress(xp: store.profile.xp),
                tint: Theme.violet,
                height: 10
            )

            Text("\((store.level.xpCeiling - store.profile.xp).grouped) XP to Level \(store.level.index + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard(tint: Theme.violet)
    }

    private var lifetimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("All time", subtitle: "Everything Health has on record")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                StatTile(
                    title: "Lifetime steps",
                    value: health.lifetime.steps.compact,
                    systemImage: "shoeprints.fill",
                    tint: Theme.brand
                )
                StatTile(
                    title: "Distance",
                    value: Units.shortDistance(meters: health.lifetime.distanceMeters, metric: useMetric),
                    systemImage: "location.fill",
                    tint: Theme.sky
                )
                StatTile(
                    title: "Longest streak",
                    value: "\(store.streak.longest) days",
                    systemImage: "flame.fill",
                    tint: Theme.flame
                )
                StatTile(
                    title: "Goal days",
                    value: store.streak.totalGoalDays.grouped,
                    systemImage: "checkmark.seal.fill",
                    tint: Theme.mint
                )
            }
        }
    }

    private var badgeStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Badges",
                subtitle: "\(store.unlockedBadges.count) of \(Achievement.catalog.count)"
            ) {
                NavigationLink {
                    AchievementsView()
                } label: {
                    Text("See all").font(.caption.weight(.semibold))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentBadges) { badge in
                        VStack(spacing: 6) {
                            Image(systemName: badge.symbol)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(badge.tier.tint)
                                .frame(width: 50, height: 50)
                                .background(badge.tier.tint.opacity(0.18), in: Circle())
                            Text(badge.title)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                        }
                        .frame(width: 68)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .glassCard()
    }

    private var links: some View {
        VStack(spacing: 0) {
            NavigationLink {
                AchievementsView()
            } label: {
                linkRow("Badges", "rosette", Theme.gold)
            }
            Divider().opacity(0.4)
            NavigationLink {
                SettingsView()
            } label: {
                linkRow("Settings", "gearshape.fill", Theme.brand)
            }
        }
        .glassCard(padding: 0)
        .foregroundStyle(.primary)
    }

    private func linkRow(_ title: String, _ symbol: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: Derived

    /// Earned badges first (newest first), then whatever is closest to unlocking,
    /// so the strip is never empty on day one.
    private var recentBadges: [Achievement] {
        let earned = store.unlockedBadges
            .sorted { $0.value > $1.value }
            .compactMap { Achievement.byID($0.key) }

        guard earned.count < 6 else { return Array(earned.prefix(8)) }

        let locked = Achievement.catalog.filter { store.unlockedBadges[$0.id] == nil }
        return earned + Array(locked.prefix(8 - earned.count))
    }

    private func inviteMessage(code: String) -> String {
        """
        Walking with me on StepCounting? Join with code \(code).
        """
    }
}

// MARK: - Edit

struct EditProfileView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "🏃"
    @State private var accentIndex = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Your name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Avatar") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                        spacing: 10
                    ) {
                        ForEach(UserProfile.avatarChoices, id: \.self) { choice in
                            Button {
                                emoji = choice
                            } label: {
                                Text(choice)
                                    .font(.title3)
                                    .frame(width: 38, height: 38)
                                    .background {
                                        Circle().fill(emoji == choice
                                                      ? Theme.accent(accentIndex).opacity(0.25)
                                                      : Color.primary.opacity(0.05))
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Colour") {
                    HStack(spacing: 12) {
                        ForEach(Theme.accents.indices, id: \.self) { index in
                            Button {
                                accentIndex = index
                            } label: {
                                Circle()
                                    .fill(Theme.accent(index))
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        Circle().strokeBorder(.white, lineWidth: accentIndex == index ? 3 : 0)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                Section {
                    Text("This is what your crews see. Changes reach them the next time your phone publishes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateProfile(name: name, emoji: emoji, accentIndex: accentIndex)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = store.profile.displayName
                emoji = store.profile.avatarEmoji
                accentIndex = store.profile.accentIndex
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(HealthKitManager.preview())
        .environmentObject(AppStore.preview())
}
