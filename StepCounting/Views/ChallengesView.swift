import SwiftUI

/// Everything competitive, in one place.
struct ChallengesView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var store: AppStore

    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000
    @AppStorage(SettingsKeys.useMetric) private var useMetric = true

    @State private var templateToStart: ChallengeTemplate?
    @State private var showingCustom = false
    @State private var showingCreateCrew = false
    @State private var showingJoinCrew = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(tint: Theme.violet, secondary: Theme.coral)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                        if store.crews.isEmpty {
                            needsCrew
                        } else {
                            active
                            templates
                            finished
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .refreshable { await health.refreshAll() }
            }
            .navigationTitle("Challenges")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCustom = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(store.crews.isEmpty)
                }
            }
            .sheet(isPresented: $showingCustom) {
                NewChallengeView()
            }
            .sheet(item: $templateToStart) { template in
                StartTemplateSheet(template: template)
            }
            .sheet(isPresented: $showingCreateCrew) { CreateCrewView() }
            .sheet(isPresented: $showingJoinCrew) { JoinCrewView() }
        }
    }

    // MARK: Sections

    private var needsCrew: some View {
        VStack(spacing: 16) {
            InfoState(
                systemImage: "person.2.badge.plus",
                title: "Challenges need people",
                message: "Join or start a crew first — then race them to a target, pool a million steps, or walk the Camino together.",
                tint: Theme.violet
            )
            HStack(spacing: 12) {
                Button("Create a crew") { showingCreateCrew = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.violet)
                Button("Join with a code") { showingJoinCrew = true }
                    .buttonStyle(.bordered)
            }
            .font(.subheadline.weight(.semibold))
        }
        .glassCard()
    }

    @ViewBuilder
    private var active: some View {
        if store.activeChallenges.isEmpty {
            VStack(spacing: 8) {
                Text("🏁")
                    .font(.system(size: 34))
                Text("Nothing running")
                    .font(.headline)
                Text("Pick a challenge below — most take one tap to start.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Running now", subtitle: "\(store.activeChallenges.count) live")

                ForEach(store.activeChallenges) { challenge in
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

    private var templates: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Start something", subtitle: "One tap, no setup") {
                Button("Custom") { showingCustom = true }
                    .font(.caption.weight(.semibold))
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(ChallengeTemplate.catalog) { template in
                    Button {
                        templateToStart = template
                    } label: {
                        TemplateTile(template: template)
                    }
                    .buttonStyle(.pressable)
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    @ViewBuilder
    private var finished: some View {
        if !store.finishedChallenges.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Finished")

                ForEach(store.finishedChallenges.prefix(6)) { challenge in
                    NavigationLink {
                        ChallengeDetailView(challenge: challenge)
                    } label: {
                        FinishedRow(
                            challenge: challenge,
                            winner: ChallengeEngine.winner(of: challenge, inputs: inputs)
                        )
                    }
                    .buttonStyle(.pressable)
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private var inputs: ChallengeEngine.Inputs {
        store.challengeInputs(health: health, goal: dailyGoal, useMetric: useMetric)
    }
}

// MARK: - Template tile

struct TemplateTile: View {
    let template: ChallengeTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(template.emoji)
                .font(.system(size: 28))

            Text(template.title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)

            Text(template.blurb)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Image(systemName: template.format.symbol)
                Text("\(template.days) days")
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.accent(template.accentIndex))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: Theme.accent(template.accentIndex))
    }
}

// MARK: - Finished row

struct FinishedRow: View {
    let challenge: Challenge
    let winner: Standing?

    var body: some View {
        HStack(spacing: 12) {
            Text(challenge.emoji)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(challenge.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if winner?.isYou == true {
                Text("🏆")
                    .font(.title3)
            }
        }
        .glassCard(radius: Theme.tightRadius, padding: 12)
    }

    private var subtitle: String {
        guard let winner else {
            return "Ended \(challenge.endDate.monthDay)"
        }
        return winner.isYou ? "You won" : "\(winner.name) won"
    }
}

// MARK: - Start sheet

/// Confirms which crew a template runs in.
///
/// Skipped entirely when there's only one crew — a modal that asks a question
/// with one possible answer is just a tax.
struct StartTemplateSheet: View {
    let template: ChallengeTemplate

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCrewID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(tint: Theme.accent(template.accentIndex))

                ScrollView {
                    VStack(spacing: 20) {
                        header

                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader("Which crew?")
                            ForEach(store.crews) { crew in
                                crewRow(crew)
                            }
                        }

                        Button {
                            start()
                        } label: {
                            Text("Start challenge")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent(template.accentIndex))
                        .disabled(selectedCrewID == nil)
                    }
                    .padding(Theme.screenPadding)
                }
            }
            .navigationTitle("New challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { selectedCrewID = selectedCrewID ?? store.crews.first?.id }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(template.emoji)
                .font(.system(size: 54))
            Text(template.title)
                .font(.title2.weight(.bold))
            Text(template.blurb)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Pill(text: template.format.title, systemImage: template.format.symbol,
                     tint: Theme.accent(template.accentIndex))
                Pill(text: "\(template.days) days", systemImage: "calendar")
                if template.target > 0 {
                    Pill(text: template.metric.format(template.target, metric: true),
                         systemImage: template.metric.symbol, tint: Theme.mint)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 10)
    }

    private func crewRow(_ crew: Crew) -> some View {
        Button {
            selectedCrewID = crew.id
            Haptics.tap()
        } label: {
            HStack(spacing: 12) {
                Text(crew.emoji).font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(crew.name).font(.subheadline.weight(.semibold))
                    Text("\(crew.memberIDs.count) members")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: selectedCrewID == crew.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedCrewID == crew.id ? crew.tint : .secondary)
            }
            .glassCard(radius: Theme.tightRadius, padding: 13)
        }
        .buttonStyle(.pressable)
        .foregroundStyle(.primary)
    }

    private func start() {
        guard let id = selectedCrewID, let crew = store.crews.first(where: { $0.id == id }) else { return }
        store.start(template: template, in: crew)
        dismiss()
    }
}

#Preview {
    ChallengesView()
        .environmentObject(HealthKitManager.preview())
        .environmentObject(AppStore.preview())
}
