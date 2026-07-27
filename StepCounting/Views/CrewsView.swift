import SwiftUI

/// Crews, invitations, and the activity feed.
struct CrewsView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var store: AppStore

    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000

    @State private var showingJoin = false
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(tint: Theme.mint, secondary: Theme.brand)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                        inviteCard
                        crewList
                        feedSection
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .refreshable { await health.refreshAll() }
            }
            .navigationTitle("Crews")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingCreate = true
                        } label: {
                            Label("Create a crew", systemImage: "plus.circle")
                        }
                        Button {
                            showingJoin = true
                        } label: {
                            Label("Join with a code", systemImage: "number")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingJoin) { JoinCrewView() }
            .sheet(isPresented: $showingCreate) { CreateCrewView() }
        }
    }

    // MARK: Sections

    /// The invite code, given prime position.
    ///
    /// Every crew someone joins makes them meaningfully more likely to stick
    /// around, and this is the one screen element that turns a user into two.
    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                AvatarView(
                    emoji: store.profile.avatarEmoji,
                    accentIndex: store.profile.accentIndex,
                    size: 44,
                    isYou: true
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text("Your invite code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(store.profile.inviteCode)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .tracking(3)
                }
                Spacer(minLength: 0)
            }

            Text("Send this to a friend — they enter it under Join with a code and you'll see each other's days.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ShareLink(item: inviteMessage) {
                Label("Invite a friend", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Theme.brand.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
        }
        .glassCard(tint: Theme.accent(store.profile.accentIndex))
    }

    @ViewBuilder
    private var crewList: some View {
        if store.crews.isEmpty {
            VStack(spacing: 14) {
                InfoState(
                    systemImage: "person.2.badge.plus",
                    title: "No crews yet",
                    message: "Crews are small and invite-only — no global leaderboard, no strangers. Start one or join with a code.",
                    tint: Theme.mint
                )
                HStack(spacing: 12) {
                    Button("Create") { showingCreate = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.mint)
                    Button("Join with code") { showingJoin = true }
                        .buttonStyle(.bordered)
                }
            }
            .glassCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Your crews", subtitle: "\(store.crews.count) joined")

                ForEach(store.crews) { crew in
                    NavigationLink {
                        CrewDetailView(crew: crew)
                    } label: {
                        CrewRow(
                            crew: crew,
                            members: store.members(of: crew),
                            yourRank: rank(in: crew)
                        )
                    }
                    .buttonStyle(.pressable)
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    @ViewBuilder
    private var feedSection: some View {
        let events = store.feed()
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader("Activity", subtitle: "Cheer someone on")

                VStack(spacing: 0) {
                    ForEach(events.prefix(12)) { event in
                        FeedRow(event: event) { store.toggleCheer(event) }
                        if event.id != events.prefix(12).last?.id {
                            Divider().opacity(0.35)
                        }
                    }
                }
                .glassCard()
            }
        }
    }

    // MARK: Derived

    private var inviteMessage: String {
        """
        Walking with me on StepCounting? My invite code is \(store.profile.inviteCode) — \
        add it and we can see each other's daily steps and race a few challenges.
        """
    }

    private func rank(in crew: Crew) -> Int? {
        store.todayLeaderboard(yourSteps: health.today.steps, crew: crew)
            .first(where: \.isYou)?
            .rank
    }
}

// MARK: - Crew row

struct CrewRow: View {
    let crew: Crew
    let members: [Friend]
    var yourRank: Int?

    var body: some View {
        HStack(spacing: 13) {
            Text(crew.emoji)
                .font(.system(size: 26))
                .frame(width: 46, height: 46)
                .background(crew.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(crew.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: -8) {
                    ForEach(members.prefix(5)) { member in
                        AvatarView(emoji: member.avatarEmoji, accentIndex: member.accentIndex, size: 24)
                    }
                    if members.count > 5 {
                        Text("+\(members.count - 5)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 12)
                    }
                }
            }

            Spacer(minLength: 0)

            if let yourRank {
                VStack(spacing: 1) {
                    Text("#\(yourRank)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                    Text("today")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(crew.tint)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .glassCard(tint: crew.tint)
    }
}

// MARK: - Join

struct JoinCrewView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var error: String?
    @State private var isJoining = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(tint: Theme.mint)

                VStack(spacing: 20) {
                    Text("🔑")
                        .font(.system(size: 56))
                        .padding(.top, 24)

                    Text("Enter an invite code")
                        .font(.title2.weight(.bold))

                    Text("Six characters, from a friend or a crew you've been invited to.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    TextField("AB3K9X", text: $code)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.vertical, 16)
                        .glassCard(radius: 16, padding: 0)
                        .onChange(of: code) { _, newValue in
                            let cleaned = InviteCode.normalize(newValue)
                            if cleaned != newValue { code = cleaned }
                            error = nil
                        }

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Theme.coral)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await join() }
                    } label: {
                        Group {
                            if isJoining {
                                ProgressView()
                            } else {
                                Text("Join crew")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.mint)
                    .disabled(code.count < 4 || isJoining)

                    Spacer()
                }
                .padding(Theme.screenPadding)
            }
            .navigationTitle("Join a crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func join() async {
        isJoining = true
        defer { isJoining = false }
        do {
            try await store.joinCrew(code: code)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Create

struct CreateCrewView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "👟"
    @State private var accentIndex = 3

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Sunday Walkers", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Icon") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                        spacing: 10
                    ) {
                        ForEach(Crew.emojiChoices, id: \.self) { choice in
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
                    Text("You'll get a code to share. Anyone with it can see your daily totals — and you'll see theirs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await store.createCrew(name: name, emoji: emoji, accentIndex: accentIndex)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    CrewsView()
        .environmentObject(HealthKitManager.preview())
        .environmentObject(AppStore.preview())
}
