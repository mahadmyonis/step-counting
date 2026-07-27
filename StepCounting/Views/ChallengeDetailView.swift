import SwiftUI

/// Full standings and progress for one challenge.
struct ChallengeDetailView: View {
    let challenge: Challenge

    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000
    @AppStorage(SettingsKeys.useMetric) private var useMetric = true

    @State private var confirmingLeave = false

    var body: some View {
        ZStack {
            ScreenBackground(tint: challenge.tint, secondary: Theme.violet)

            ScrollView {
                VStack(spacing: Theme.sectionSpacing) {
                    header
                    if let route = challenge.route {
                        RouteProgressView(route: route, progress: headlineProgress)
                            .card()
                    }
                    if challenge.format.isCooperative {
                        teamCard
                    }
                    standingsCard
                    detailsCard
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .refreshable { await health.refreshAll() }
        }
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let card = shareCard {
                        ShareCardButton(card: card, label: "Share standings")
                    }
                    Button(role: .destructive) {
                        confirmingLeave = true
                    } label: {
                        Label("Leave challenge", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Leave \(challenge.title)?",
            isPresented: $confirmingLeave,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                store.leaveChallenge(challenge)
                dismiss()
            }
        } message: {
            Text("Your progress in this challenge won't be kept.")
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 10) {
            Text(challenge.emoji)
                .font(.system(size: 52))

            Text(challenge.format.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Pill(text: challenge.status(), systemImage: "clock", tint: challenge.tint)
                if challenge.target > 0 {
                    Pill(
                        text: challenge.metric.format(challenge.target, metric: useMetric),
                        systemImage: challenge.metric.symbol,
                        tint: Theme.mint
                    )
                }
            }

            if let pace = ChallengeEngine.paceMessage(for: challenge, inputs: inputs) {
                Text(pace)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .card(tint: challenge.tint)
    }

    private var teamCard: some View {
        let team = ChallengeEngine.teamTotal(for: challenge, inputs: inputs)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Team total", subtitle: "Everyone's steps pooled") {
                Text("\(Int(team.progress * 100))%")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(challenge.tint)
            }

            ProgressBarRow(progress: team.progress, tint: challenge.tint, height: 12)

            HStack {
                Text(challenge.metric.format(team.value, metric: useMetric))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Spacer()
                Text("of \(challenge.metric.format(challenge.target, metric: useMetric))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var standingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                challenge.format.isCooperative ? "Contributions" : "Standings",
                subtitle: "\(challenge.participantIDs.count) taking part"
            )

            ForEach(standings) { standing in
                StandingRow(
                    standing: standing,
                    metric: challenge.metric,
                    useMetric: useMetric,
                    showsRank: !challenge.format.isCooperative
                )
            }
        }
        .card()
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow("Format", challenge.format.title, "flag.checkered")
            Divider().opacity(0.4)
            detailRow("Measured in", challenge.metric.title, challenge.metric.symbol)
            Divider().opacity(0.4)
            detailRow(
                "Window",
                "\(challenge.startDate.monthDay) – \(challenge.endDate.monthDay)",
                "calendar"
            )
            if let crew = store.crew(challenge.crewID) {
                Divider().opacity(0.4)
                detailRow("Crew", "\(crew.emoji) \(crew.name)", "person.2.fill")
            }
        }
        .card(padding: 0)
    }

    private func detailRow(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(challenge.tint)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: Derived

    private var inputs: ChallengeEngine.Inputs {
        store.challengeInputs(health: health, goal: dailyGoal, useMetric: useMetric)
    }

    private var standings: [Standing] {
        ChallengeEngine.standings(for: challenge, inputs: inputs)
    }

    private var headlineProgress: Double {
        ChallengeEngine.headlineProgress(for: challenge, inputs: inputs)
    }

    private var shareCard: ShareCard? {
        guard let you = ChallengeEngine.yourStanding(in: challenge, inputs: inputs) else { return nil }
        return ShareCard(
            headline: challenge.format.isCooperative
                ? "\(Int(headlineProgress * 100))% of \(challenge.title)"
                : "\(ordinal(you.rank)) in \(challenge.title)",
            subheadline: challenge.metric.format(you.value, metric: useMetric),
            profile: store.profile,
            streak: store.streak.current,
            badgeTitle: challenge.emoji + " " + challenge.format.title,
            accent: challenge.tint,
            inviteCode: store.shareableInviteCode
        )
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

#Preview {
    NavigationStack {
        ChallengeDetailView(
            challenge: ChallengeTemplate.catalog[5].makeChallenge(
                crewID: nil, participantIDs: [], createdByID: UUID()
            )
        )
        .environmentObject(HealthKitManager.preview())
        .environmentObject(AppStore.preview())
    }
}
