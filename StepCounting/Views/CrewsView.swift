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
                ScreenBackground(tint: Theme.mint, secondary: Theme.brand)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                        cloudBanner
                        inviteCard
                        crewList
                        feedSection
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
            .navigationTitle("Crews")
            .task {
                await store.refreshCloudStatus()
                await store.syncCrews(history: health.history)
            }
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
    /// Codes belong to crews, so when there isn't one yet this becomes a prompt
    /// to make one rather than a code that leads nowhere.
    @ViewBuilder
    private var inviteCard: some View {
        if let code = store.shareableInviteCode {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    AvatarView(
                        emoji: store.profile.avatarEmoji,
                        accentIndex: store.profile.accentIndex,
                        size: 44,
                        isYou: true
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Invite code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(code)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                Text("Send this to a friend — they enter it under Join with a code, and you'll see each other's days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ShareLink(item: inviteMessage(code: code)) {
                    Label("Invite a friend", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            Theme.brand.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )
                }
            }
            .card(tint: Theme.accent(store.profile.accentIndex))
        }
    }

    /// Explains, in plain language, when crews can't work right now.
    @ViewBuilder
    private var cloudBanner: some View {
        if let reason = store.cloudStatus.reason {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "icloud.slash")
                    .foregroundStyle(Theme.flame)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Crews are offline")
                        .font(.subheadline.weight(.semibold))
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .card(radius: Theme.tightRadius, padding: 13)
        }
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
            .card()
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
                .card()
            }
        }
    }

    // MARK: Derived

    private func inviteMessage(code: String) -> String {
        """
        Walking with me on StepCounting? Join with code \(code) — \
        we'll see each other's daily steps and can race a few challenges.
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
        HStack(spacing: Theme.Space.md) {
            Text(crew.emoji)
                .font(.system(size: 26))
                .frame(width: 46, height: 46)
                .background(
                    crew.tint.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.chip + 2, style: .continuous)
                )

            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                // The name gets the row's flexible width. Previously a rank
                // block and a chevron squeezed it into "Sample Cr…".
                Text(crew.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Theme.Space.sm) {
                    HStack(spacing: -7) {
                        ForEach(members.prefix(4)) { member in
                            AvatarView(emoji: member.avatarEmoji, accentIndex: member.accentIndex, size: 22)
                        }
                    }
                    Text(memberCaption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let yourRank {
                Text("#\(yourRank)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(crew.tint)
                    .padding(.horizontal, Theme.Space.sm)
                    .padding(.vertical, 5)
                    .background(crew.tint.opacity(0.13), in: Capsule())
                    .fixedSize()
                    .accessibilityLabel("You are number \(yourRank) today")
            }
        }
        .card(tint: crew.tint)
    }

    private var memberCaption: String {
        let count = members.count
        if count > 4 { return "+\(count - 4) more" }
        return count == 1 ? "1 member" : "\(count) members"
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
                ScreenBackground(tint: Theme.mint)

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
                        .card(radius: 16, padding: 0)
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
                        if isJoining {
                            ProgressView().tint(.white)
                        } else {
                            Text("Join crew")
                        }
                    }
                    .buttonStyle(.prominent(Theme.mint))
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
    @State private var isCreating = false
    @State private var error: String?

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
                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Theme.coral)
                    }
                    Text("The crew lives in your iCloud and is shared only with people you give the code to. Everyone's phone reads its own Health data and publishes a daily total — nobody can see anyone else's Health app.")
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
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") { Task { await create() } }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func create() async {
        isCreating = true
        defer { isCreating = false }
        do {
            try await store.createCrew(name: name, emoji: emoji, accentIndex: accentIndex)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    CrewsView()
        .environmentObject(HealthKitManager.preview())
        .environmentObject(AppStore.preview())
}
