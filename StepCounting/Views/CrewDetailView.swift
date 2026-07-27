import SwiftUI

/// One crew: who's in it, how today's going, and what you're racing.
struct CrewDetailView: View {
    let crew: Crew

    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000
    @AppStorage(SettingsKeys.useMetric) private var useMetric = true

    @State private var window: Window = .today
    @State private var confirmingLeave = false

    /// Today resets daily so nobody can coast; the week view rewards volume.
    private enum Window: String, CaseIterable, Identifiable {
        case today = "Today"
        case week = "This week"

        var id: String { rawValue }
        var days: Int { self == .today ? 1 : 7 }
    }

    var body: some View {
        ZStack {
            ScreenBackground(tint: crew.tint, secondary: Theme.brand)

            ScrollView {
                VStack(spacing: Theme.sectionSpacing) {
                    header
                    board
                    challenges
                    inviteCard
                    if crew.isSimulated { simulationNote }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await health.refreshAll()
                await store.syncCrews(history: health.history, force: true)
            }
        }
        .task { await store.syncCrews(history: health.history) }
        .navigationTitle(crew.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: shareMessage) {
                        Label("Share invite code", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        confirmingLeave = true
                    } label: {
                        Label("Leave crew", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Leave \(crew.name)?",
            isPresented: $confirmingLeave,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                store.leaveCrew(crew)
                dismiss()
            }
        } message: {
            Text("Challenges that belong to this crew will be removed too.")
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 10) {
            Text(crew.emoji)
                .font(.system(size: 48))

            HStack(spacing: 8) {
                Pill(text: "\(crew.memberIDs.count) members", systemImage: "person.2.fill", tint: crew.tint)
                if crew.isCloudBacked {
                    Pill(text: syncCaption, systemImage: "arrow.triangle.2.circlepath", tint: Theme.mint)
                } else {
                    Pill(text: "since \(crew.createdAt.monthDay)", systemImage: "calendar", tint: Theme.brand)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .card(tint: crew.tint)
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Window", selection: $window) {
                ForEach(Window.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            ForEach(entries) { entry in
                TodayBoardRow(entry: entry)
                if entry.id != entries.last?.id {
                    Divider().opacity(0.35)
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private var challenges: some View {
        let crewChallenges = store.challenges
            .filter { $0.crewID == crew.id && !$0.hasEnded() }
            .sorted { $0.endDate < $1.endDate }

        if !crewChallenges.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Racing", subtitle: "\(crewChallenges.count) live in this crew")

                ForEach(crewChallenges) { challenge in
                    NavigationLink {
                        ChallengeDetailView(challenge: challenge)
                    } label: {
                        ChallengeCard(
                            challenge: challenge,
                            progress: ChallengeEngine.headlineProgress(for: challenge, inputs: inputs),
                            yourStanding: ChallengeEngine.yourStanding(in: challenge, inputs: inputs),
                            pace: ChallengeEngine.paceMessage(for: challenge, inputs: inputs),
                            participantCount: challenge.participantIDs.count,
                            useMetric: useMetric
                        )
                    }
                    .buttonStyle(.pressable)
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Invite code")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text(crew.inviteCode)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .tracking(3)
                Spacer()
                ShareLink(item: shareMessage) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline)
                }
            }
        }
        .card()
    }

    private var simulationNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Theme.sky)
            Text("This is the sample crew — these walkers are generated on your device and their step histories are made up. Create or join a real crew to walk with actual people.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(radius: Theme.tightRadius, padding: 13)
    }

    // MARK: Derived

    private var inputs: ChallengeEngine.Inputs {
        store.challengeInputs(health: health, goal: dailyGoal, useMetric: useMetric)
    }

    /// How fresh the crew's numbers are — worth showing, because a leaderboard
    /// nobody can date is a leaderboard nobody trusts.
    private var syncCaption: String {
        if store.isSyncing { return "Syncing…" }
        guard let synced = crew.lastSyncedAt else { return "Not synced yet" }
        if Date().timeIntervalSince(synced) < 90 { return "Up to date" }
        return "Synced \(synced.formatted(.relative(presentation: .numeric)))"
    }

    private var entries: [LeaderboardEntry] {
        switch window {
        case .today:
            return store.todayLeaderboard(yourSteps: health.today.steps, crew: crew)
        case .week:
            return weekLeaderboard()
        }
    }

    /// Seven-day totals, computed the same way the challenge engine does it so
    /// the two screens can never disagree.
    private func weekLeaderboard() -> [LeaderboardEntry] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today

        let rows: [(friend: Friend, steps: Int)] = crew.memberIDs.compactMap { id in
            guard let friend = store.roster[id] else { return nil }
            if friend.isYou {
                return (friend, health.history.steps(from: start, to: today, calendar: calendar))
            }
            var total = 0
            var day = start
            while day <= today {
                total += friend.steps(on: day, calendar: calendar, now: now)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            return (friend, total)
        }

        let leader = rows.map(\.steps).max() ?? 0
        let sorted = rows.sorted { lhs, rhs in
            if lhs.steps != rhs.steps { return lhs.steps > rhs.steps }
            return lhs.friend.id.uuidString < rhs.friend.id.uuidString
        }

        return sorted.enumerated().map { index, row in
            LeaderboardEntry(
                id: row.friend.id,
                name: row.friend.isYou ? "You" : row.friend.displayName,
                emoji: row.friend.avatarEmoji,
                accentIndex: row.friend.accentIndex,
                isYou: row.friend.isYou,
                value: row.steps,
                rank: index + 1,
                share: leader > 0 ? Double(row.steps) / Double(leader) : 0
            )
        }
    }

    private var shareMessage: String {
        """
        Join \(crew.emoji) \(crew.name) on StepCounting — the invite code is \(crew.inviteCode).
        """
    }
}

#Preview {
    NavigationStack {
        CrewDetailView(crew: DemoSocialService.sampleCrew(owner: UserProfile()).crew)
            .environmentObject(HealthKitManager.preview())
            .environmentObject(AppStore.preview())
    }
}
