import SwiftUI
import Charts

/// The home screen.
///
/// Ordered by what people actually open the app to check: how am I doing today,
/// is my streak safe, where am I against my crew, and what's live right now.
/// Everything below the ring is skippable; nothing above it is.
struct DashboardView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var store: AppStore

    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000
    @AppStorage(SettingsKeys.useMetric) private var useMetric = true

    @State private var showingCreateCrew = false
    @State private var showingJoinCrew = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(tint: Theme.accent(store.profile.accentIndex))

                ScrollView {
                    VStack(spacing: Theme.sectionSpacing) {
                        switch health.authorizationStatus {
                        case .authorized:
                            content
                        case .notDetermined:
                            InfoState(
                                systemImage: "heart.text.square",
                                title: "Connecting to Health",
                                message: "Grant access to your step data to see your activity.",
                                actionTitle: "Connect Health",
                                action: { Task { await connect() } }
                            )
                            .card()
                        case .denied:
                            InfoState(
                                systemImage: "hand.raised.slash",
                                title: "Health Access Denied",
                                message: "Enable step, distance, and energy access in Settings → Health → Data Access to use StepCounting.",
                                tint: Theme.coral
                            )
                            .card()
                        case .unavailable:
                            InfoState(
                                systemImage: "exclamationmark.triangle",
                                title: "Health Unavailable",
                                message: "Health data isn't available on this device.",
                                tint: Theme.flame
                            )
                            .card()
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .refreshable { await health.refreshAll() }
            }
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareCardButton(card: shareCard, label: "Share")
                }
            }
            .sheet(isPresented: $showingCreateCrew) { CreateCrewView() }
            .sheet(isPresented: $showingJoinCrew) { JoinCrewView() }
        }
    }

    // MARK: Sections

    private var content: some View {
        VStack(spacing: Theme.sectionSpacing) {
            hero
            tiles
            StreakCard(
                streak: store.streak,
                status: streakStatus,
                onUseFreeze: { _ = store.useFreeze(history: health.history, goal: dailyGoal) }
            )
            crewBoard
            liveChallenges
            hourlyChart
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            GoalRing(steps: health.today.steps, goal: dailyGoal, caption: ringCaption)
                .padding(.top, 4)

            if health.today.metGoal(dailyGoal) {
                Pill(
                    text: "\(Int((Double(health.today.steps) / Double(max(dailyGoal, 1))) * 100))% of goal",
                    systemImage: "checkmark.seal.fill",
                    tint: Theme.mint
                )
            }
        }
    }

    private var tiles: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            StatTile(
                title: "Distance",
                value: health.today.distanceString(metric: useMetric),
                systemImage: "location.fill",
                tint: Theme.sky
            )
            StatTile(
                title: "Active Energy",
                value: "\(Int(health.today.activeEnergyKcal)) kcal",
                systemImage: "flame.fill",
                tint: Theme.flame
            )
            StatTile(
                title: "Flights",
                value: "\(health.today.flightsClimbed)",
                systemImage: "stairs",
                tint: Theme.violet
            )
            StatTile(
                title: "Exercise",
                value: "\(health.today.exerciseMinutes) min",
                systemImage: "figure.run",
                tint: Theme.mint
            )
        }
    }

    @ViewBuilder
    private var crewBoard: some View {
        if let crew = store.crews.first {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "\(crew.emoji) \(crew.name)", subtitle: "Today so far") {
                    NavigationLink {
                        CrewDetailView(crew: crew)
                    } label: {
                        Text("See all")
                            .font(.caption.weight(.semibold))
                    }
                }

                VStack(spacing: 0) {
                    ForEach(Array(todayBoard.prefix(4))) { entry in
                        TodayBoardRow(entry: entry)
                        if entry.id != todayBoard.prefix(4).last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }

                if let you = todayBoard.first(where: \.isYou), you.rank > 1 {
                    Text(gapMessage(for: you))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .card(tint: crew.tint)
        } else {
            emptyCrewPrompt
        }
    }

    private var emptyCrewPrompt: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Text("👥")
                    .font(.system(size: 30))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Walk with someone")
                        .font(.headline)
                    Text("People in a crew stick with it far longer than people walking alone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button("Create a crew") { showingCreateCrew = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand)
                Button("Join with a code") { showingJoinCrew = true }
                    .buttonStyle(.bordered)
            }
            .font(.subheadline.weight(.semibold))
        }
        .card(tint: Theme.brand)
    }

    @ViewBuilder
    private var liveChallenges: some View {
        if !store.activeChallenges.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Live now", subtitle: "\(store.activeChallenges.count) running")

                ForEach(store.activeChallenges.prefix(2)) { challenge in
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

    @ViewBuilder
    private var hourlyChart: some View {
        let buckets = health.hourlyToday.filter { $0.steps > 0 }
        if !buckets.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("When you moved", subtitle: busiestCaption)

                Chart(health.hourlyToday) { bucket in
                    BarMark(
                        x: .value("Hour", bucket.hour),
                        y: .value("Steps", bucket.steps),
                        width: .fixed(6)
                    )
                    .foregroundStyle(Theme.fill(Theme.accent(store.profile.accentIndex)))
                    .cornerRadius(3)
                }
                .chartXScale(domain: 0...23)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(HourlySteps(hour: hour, steps: 0).label)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let steps = value.as(Int.self) {
                                Text(steps.compact).font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 140)
            }
            .card()
        }
    }

    // MARK: Derived

    private var inputs: ChallengeEngine.Inputs {
        store.challengeInputs(health: health, goal: dailyGoal, useMetric: useMetric)
    }

    private var todayBoard: [LeaderboardEntry] {
        guard let crew = store.crews.first else { return [] }
        return store.todayLeaderboard(yourSteps: health.today.steps, crew: crew)
    }

    private var streakStatus: StreakStatus {
        StreakEngine.status(
            store.streak,
            today: health.today,
            goal: dailyGoal,
            history: health.history
        )
    }

    /// A number tells you where you are; a walking time tells you what to do
    /// about it, which is the difference between a readout and a nudge.
    private var ringCaption: String? {
        let remaining = dailyGoal - health.today.steps
        guard remaining > 0 else { return nil }
        let minutes = max(1, Int((Double(remaining) / 110).rounded()))
        return "\(remaining.grouped) to go · about \(minutes) min"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = store.profile.displayName
        switch hour {
        case 0..<5: return "Still up, \(name)?"
        case 5..<12: return "Morning, \(name)"
        case 12..<17: return "Afternoon, \(name)"
        case 17..<22: return "Evening, \(name)"
        default: return "Night, \(name)"
        }
    }

    private var busiestCaption: String {
        guard let peak = health.hourlyToday.max(by: { $0.steps < $1.steps }), peak.steps > 0 else {
            return "No steps logged yet"
        }
        return "Busiest around \(peak.label)"
    }

    private var shareCard: ShareCard {
        ShareCard(
            headline: "\(health.today.steps.grouped) steps",
            subheadline: health.today.metGoal(dailyGoal)
                ? "Goal hit — \(health.today.distanceString(metric: useMetric))"
                : "\(health.today.distanceString(metric: useMetric)) so far today",
            profile: store.profile,
            streak: store.streak.current,
            accent: Theme.accent(store.profile.accentIndex),
            inviteCode: store.shareableInviteCode
        )
    }

    private func gapMessage(for you: LeaderboardEntry) -> String {
        guard let leader = todayBoard.first else { return "" }
        let gap = max(leader.value - you.value, 0)
        guard gap > 0 else { return "You're level with the lead." }
        return "\(gap.grouped) steps behind \(leader.name) — about \(max(1, gap / 110)) minutes of walking."
    }

    private func connect() async {
        await health.requestAuthorization()
        await health.refreshAll()
    }
}

#Preview {
    DashboardView()
        .environmentObject(HealthKitManager.preview())
        .environmentObject(AppStore.preview())
}
