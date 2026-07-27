import Foundation
import SwiftUI

/// Shared `@AppStorage` keys so views stay in sync without a store object.
enum SettingsKeys {
    static let dailyGoal = "dailyStepGoal"
    static let useMetric = "useMetricUnits"
    static let remindersEnabled = "remindersEnabled"
}

/// Everything the app knows that isn't Health data.
///
/// One object owns identity, crews, challenges, badges, streak, and the feed —
/// and one object writes them to disk. Screens read published state and call
/// intent methods; nothing else mutates this.
@MainActor
final class AppStore: ObservableObject {

    // MARK: State

    @Published private(set) var profile: UserProfile
    @Published private(set) var crews: [Crew] = []
    /// Everyone we know about, including a row for the local user.
    @Published private(set) var roster: [UUID: Friend] = [:]
    @Published private(set) var challenges: [Challenge] = []
    @Published private(set) var streak = StreakState()
    /// Badge id → the moment it was earned.
    @Published private(set) var unlockedBadges: [String: Date] = [:]
    @Published private(set) var hasOnboarded = false

    /// Presented over everything when something worth celebrating happens.
    @Published var celebration: Celebration?
    /// Non-blocking banner text for smaller confirmations.
    @Published var toast: String?
    /// Whether iCloud can back real crews right now, and why not if it can't.
    @Published private(set) var cloudStatus: SocialAvailability = .ready
    /// True while a crew sync is in flight, for the spinner in the Crews tab.
    @Published private(set) var isSyncing = false

    // MARK: Derived

    var level: Level { Level.forXP(profile.xp) }

    var you: Friend {
        Friend(
            id: profile.id,
            displayName: "You",
            avatarEmoji: profile.avatarEmoji,
            accentIndex: profile.accentIndex,
            isYou: true
        )
    }

    var activeChallenges: [Challenge] {
        challenges.filter { $0.isActive() }.sorted { $0.endDate < $1.endDate }
    }

    var finishedChallenges: [Challenge] {
        challenges.filter { $0.hasEnded() }.sorted { $0.endDate > $1.endDate }
    }

    func members(of crew: Crew) -> [Friend] {
        crew.memberIDs.compactMap { roster[$0] }
    }

    func crew(_ id: UUID?) -> Crew? {
        guard let id else { return nil }
        return crews.first { $0.id == id }
    }

    // MARK: Private

    /// The real backend. Every crew that isn't the onboarding sample goes here.
    private let cloud: SocialService
    /// Backs the sample crew only.
    private let demo = DemoSocialService()
    private let store: PersistenceStore
    /// Stops a foreground burst of Health refreshes from hammering CloudKit.
    private var lastCloudSync: Date?
    /// Guards against celebrating the same thing twice in one day.
    private var celebratedGoalDay: Date?
    private var celebratedStreakMilestone: Int = 0
    /// Your own milestone posts. Crew-mates' events are generated on read.
    private var ownEvents: [FeedEvent] = []
    private var cheeredEventIDs: Set<String> = []

    // MARK: Init

    init(cloud: SocialService = CloudKitSocialService(), store: PersistenceStore = .documents()) {
        self.cloud = cloud
        self.store = store
        self.profile = UserProfile()
        load()
    }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var profile: UserProfile
        var crews: [Crew]
        var roster: [Friend]
        var challenges: [Challenge]
        var streak: StreakState
        var unlockedBadges: [String: Date]
        var hasOnboarded: Bool
        var ownEvents: [FeedEvent]
        var cheeredEventIDs: [String]
        var celebratedGoalDay: Date?
        var celebratedStreakMilestone: Int
    }

    private func load() {
        guard let snapshot: Snapshot = store.read(Snapshot.self) else {
            roster[profile.id] = you
            return
        }

        profile = snapshot.profile
        crews = snapshot.crews
        roster = Dictionary(snapshot.roster.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        challenges = snapshot.challenges
        streak = snapshot.streak
        unlockedBadges = snapshot.unlockedBadges
        hasOnboarded = snapshot.hasOnboarded
        ownEvents = snapshot.ownEvents
        cheeredEventIDs = Set(snapshot.cheeredEventIDs)
        celebratedGoalDay = snapshot.celebratedGoalDay
        celebratedStreakMilestone = snapshot.celebratedStreakMilestone
        roster[profile.id] = you
    }

    private func save() {
        let snapshot = Snapshot(
            profile: profile,
            crews: crews,
            roster: Array(roster.values),
            challenges: challenges,
            streak: streak,
            unlockedBadges: unlockedBadges,
            hasOnboarded: hasOnboarded,
            ownEvents: Array(ownEvents.suffix(150)),
            cheeredEventIDs: Array(cheeredEventIDs),
            celebratedGoalDay: celebratedGoalDay,
            celebratedStreakMilestone: celebratedStreakMilestone
        )
        store.write(snapshot)
    }

    // MARK: Onboarding

    func completeOnboarding(name: String, emoji: String, accentIndex: Int, joinSampleCrew: Bool) {
        profile.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "You" : name
        profile.avatarEmoji = emoji
        profile.accentIndex = accentIndex
        profile.joinedAt = Date()
        roster[profile.id] = you

        if joinSampleCrew {
            adopt(DemoSocialService.sampleCrew(owner: profile))
        }

        hasOnboarded = true
        save()
    }

    // MARK: Crews

    /// Re-checks whether iCloud can back crews. Cheap; safe to call on foreground.
    func refreshCloudStatus() async {
        cloudStatus = await cloud.availability()
    }

    func createCrew(name: String, emoji: String, accentIndex: Int) async throws {
        let bundle = try await cloud.createCrew(
            name: name, emoji: emoji, accentIndex: accentIndex, owner: profile
        )
        adopt(bundle)
        Haptics.success()
        toast = "\(emoji) \(name) created — share code \(bundle.crew.inviteCode)."
        save()
    }

    func joinCrew(code: String) async throws {
        let normalized = InviteCode.normalize(code)

        if let existing = crews.first(where: { $0.inviteCode == normalized }) {
            throw SocialError.alreadyJoined(existing.name)
        }

        let bundle = try await cloud.joinCrew(code: normalized, as: profile)

        if let existing = crews.first(where: { $0.cloud?.zoneName == bundle.crew.cloud?.zoneName }),
           bundle.crew.cloud != nil {
            throw SocialError.alreadyJoined(existing.name)
        }

        adopt(bundle)
        record(
            kind: .crewJoined,
            message: "joined \(bundle.crew.name)",
            id: "crew-\(profile.id.uuidString)-\(bundle.crew.id.uuidString)"
        )
        Haptics.success()
        toast = "You're in \(bundle.crew.name)."
        save()
    }

    func leaveCrew(_ crew: Crew) {
        crews.removeAll { $0.id == crew.id }
        // Drop any challenge that only existed for that crew.
        challenges.removeAll { $0.crewID == crew.id }
        pruneRoster()
        save()

        // Tell the server after the local state is already consistent — leaving
        // shouldn't appear to fail because the network did.
        Task { [cloud, profile] in
            try? await cloud.leave(crew: crew, as: profile)
        }
    }

    /// Adds a crew and its members, always including the local user.
    private func adopt(_ bundle: CrewBundle) {
        var crew = bundle.crew
        for member in bundle.members {
            roster[member.id] = member
        }
        var ids = bundle.members.map(\.id)
        ids.insert(profile.id, at: 0)
        crew.memberIDs = ids

        if let index = crews.firstIndex(where: { $0.id == crew.id }) {
            crews[index] = crew
        } else {
            crews.append(crew)
        }
        roster[profile.id] = you
    }

    /// Forgets people who are no longer in any crew.
    private func pruneRoster() {
        let keep = Set(crews.flatMap(\.memberIDs) + challenges.flatMap(\.participantIDs) + [profile.id])
        roster = roster.filter { keep.contains($0.key) }
    }

    // MARK: Challenges

    func start(template: ChallengeTemplate, in crew: Crew) {
        let challenge = template.makeChallenge(
            crewID: crew.id,
            participantIDs: crew.memberIDs,
            createdByID: profile.id
        )
        challenges.append(challenge)
        record(
            kind: .challengeJoined,
            message: "started \(challenge.title)",
            id: "start-\(challenge.id.uuidString)"
        )
        Haptics.success()
        toast = "\(challenge.emoji) \(challenge.title) is live."
        save()
    }

    func createChallenge(
        title: String,
        emoji: String,
        format: ChallengeFormat,
        metric: ChallengeMetric,
        target: Int,
        days: Int,
        crew: Crew,
        accentIndex: Int
    ) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let challenge = Challenge(
            title: title.trimmingCharacters(in: .whitespaces).isEmpty ? "Challenge" : title,
            emoji: emoji,
            format: format,
            metric: metric,
            target: target,
            startDate: start,
            endDate: calendar.date(byAdding: .day, value: max(1, days), to: start) ?? start,
            crewID: crew.id,
            participantIDs: crew.memberIDs,
            accentIndex: accentIndex,
            createdByID: profile.id
        )
        challenges.append(challenge)
        Haptics.success()
        toast = "\(emoji) \(challenge.title) is live."
        save()
    }

    func leaveChallenge(_ challenge: Challenge) {
        challenges.removeAll { $0.id == challenge.id }
        save()
    }

    // MARK: Streak freeze

    @discardableResult
    func useFreeze(history: [DailyActivity], goal: Int) -> Bool {
        guard let day = StreakEngine.rescuableDay(streak, history: history, goal: goal) else { return false }
        streak = StreakEngine.spendFreeze(on: day, state: streak, history: history, goal: goal)
        Haptics.success()
        toast = "Streak saved. \(streak.freezesAvailable) freeze\(streak.freezesAvailable == 1 ? "" : "s") left."
        save()
        return true
    }

    // MARK: Profile

    func updateProfile(name: String, emoji: String, accentIndex: Int) {
        profile.displayName = name
        profile.avatarEmoji = emoji
        profile.accentIndex = accentIndex
        roster[profile.id] = you
        save()
    }

    /// The code to hand out when someone asks "how do I follow you?".
    ///
    /// Codes belong to crews rather than people, so this is simply the first
    /// real crew's code — and `nil` when there isn't one yet, which the UI turns
    /// into a prompt to create one rather than a dead code nobody can use.
    var shareableInviteCode: String? {
        crews.first { $0.isCloudBacked }?.inviteCode
    }

    // MARK: Feed

    /// Your crews' recent activity, newest first.
    ///
    /// Crew-mates' entries are derived from their (simulated) histories every
    /// time this is read rather than stored, so the feed can never drift out of
    /// sync with the leaderboards it sits next to.
    func feed(now: Date = Date(), calendar: Calendar = .current) -> [FeedEvent] {
        var events = ownEvents

        let memberIDs = Set(crews.flatMap(\.memberIDs)).subtracting([profile.id])
        for id in memberIDs {
            guard let friend = roster[id] else { continue }
            for dayOffset in 0..<4 {
                guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
                let startOfDay = calendar.startOfDay(for: day)
                let steps = friend.steps(on: startOfDay, calendar: calendar, now: now)
                guard steps >= 10_000 else { continue }

                let key = "goal-\(friend.id.uuidString)-\(Friend.dayKey(startOfDay, calendar: calendar))"
                // Land the post in the evening of that day rather than at
                // midnight — but never in the future, or today's entries would
                // stay invisible until 7pm.
                let evening = calendar.date(byAdding: .hour, value: 19, to: startOfDay) ?? startOfDay
                events.append(
                    FeedEvent(
                        id: key,
                        date: min(evening, now),
                        actorID: friend.id,
                        actorName: friend.displayName,
                        actorEmoji: friend.avatarEmoji,
                        accentIndex: friend.accentIndex,
                        kind: steps >= 20_000 ? .personalBest : .goalHit,
                        message: steps >= 20_000
                            ? "smashed \(steps.grouped) steps"
                            : "hit \(steps.grouped) steps",
                        cheers: Int(friend.seed % 5)
                    )
                )
            }
        }

        return events
            .map { event in
                var copy = event
                if cheeredEventIDs.contains(event.id) {
                    copy.youCheered = true
                    copy.cheers = event.cheers + 1
                }
                return copy
            }
            .filter { $0.date <= now }
            .sorted { $0.date > $1.date }
            .prefix(40)
            .map { $0 }
    }

    func toggleCheer(_ event: FeedEvent) {
        if cheeredEventIDs.contains(event.id) {
            cheeredEventIDs.remove(event.id)
        } else {
            cheeredEventIDs.insert(event.id)
            Haptics.tap()
        }
        objectWillChange.send()
        save()
    }

    private func record(kind: FeedEvent.Kind, message: String, id: String) {
        guard !ownEvents.contains(where: { $0.id == id }) else { return }
        ownEvents.append(
            FeedEvent(
                id: id,
                date: Date(),
                actorID: profile.id,
                actorName: "You",
                actorEmoji: profile.avatarEmoji,
                accentIndex: profile.accentIndex,
                kind: kind,
                message: message
            )
        )
    }

    // MARK: Sync

    /// Folds fresh Health data into streak, badges, XP, and challenge results.
    ///
    /// Called after every Health refresh. Everything here is idempotent — running
    /// it twice on the same data changes nothing and celebrates nothing twice.
    func sync(with health: HealthKitManager, goal: Int, now: Date = Date()) {
        guard hasOnboarded else { return }

        let calendar = Calendar.current
        let history = health.history

        streak = StreakEngine.recompute(streak, history: history, goal: goal, now: now, calendar: calendar)

        let context = AchievementContext(
            bestDaySteps: max(history.bestDay?.steps ?? 0, health.today.steps),
            lifetimeSteps: max(health.lifetime.steps, history.totalSteps),
            lifetimeDistanceMeters: max(health.lifetime.distanceMeters, history.totalDistanceMeters),
            lifetimeFlights: health.lifetime.flights,
            longestStreak: streak.longest,
            goalDays: streak.totalGoalDays,
            challengesWon: profile.challengesWon,
            crewCount: crews.count,
            earliestGoalHour: health.hourGoalReached(goal: goal),
            hourly: health.hourlyToday
        )

        let newBadges = unlockBadges(context: context, now: now)
        resolveFinishedChallenges(health: health, goal: goal, now: now)
        recomputeXP(history: history, goal: goal)
        celebrateIfNeeded(health: health, goal: goal, newBadges: newBadges, now: now, calendar: calendar)

        save()

        // Our own numbers just changed, so the crew's copy of them is stale.
        Task { [weak self] in
            await self?.syncCrews(history: history)
        }
    }

    /// Marks any newly satisfied badges as earned and returns them.
    private func unlockBadges(context: AchievementContext, now: Date) -> [Achievement] {
        var earned: [Achievement] = []
        for badge in Achievement.catalog
        where unlockedBadges[badge.id] == nil && badge.requirement.isSatisfied(by: context) {
            unlockedBadges[badge.id] = now
            earned.append(badge)
            record(kind: .badgeUnlocked, message: "earned \(badge.title)", id: "badge-\(badge.id)")
        }
        return earned
    }

    /// Awards wins for challenges that have finished since the last sync.
    private func resolveFinishedChallenges(health: HealthKitManager, goal: Int, now: Date) {
        let inputs = challengeInputs(health: health, goal: goal, now: now)

        for challenge in challenges where challenge.hasEnded(at: now) {
            let key = "win-\(challenge.id.uuidString)"
            guard !ownEvents.contains(where: { $0.id == key }) else { continue }
            guard let winner = ChallengeEngine.winner(of: challenge, inputs: inputs) else { continue }

            if winner.isYou {
                profile.challengesWon += 1
                record(kind: .challengeWon, message: "won \(challenge.title)", id: key)
            } else {
                record(
                    kind: .challengeWon,
                    message: "\(winner.name) won \(challenge.title)",
                    id: key
                )
            }
        }
    }

    /// XP is fully derived, never incremented — so it can't drift or double-count.
    private func recomputeXP(history: [DailyActivity], goal: Int) {
        let stepXP = XP.fromSteps(max(history.totalSteps, 0))
        let goalXP = streak.totalGoalDays * XP.goalDay
        let badgeXP = unlockedBadges.keys.compactMap { Achievement.byID($0)?.tier.xp }.reduce(0, +)
        let winXP = profile.challengesWon * XP.challengeWin
        profile.xp = stepXP + goalXP + badgeXP + winXP
    }

    /// Picks at most one thing to celebrate, highest value first.
    ///
    /// Firing three modals in a row turns a reward into an obstacle course.
    private func celebrateIfNeeded(
        health: HealthKitManager,
        goal: Int,
        newBadges: [Achievement],
        now: Date,
        calendar: Calendar
    ) {
        guard celebration == nil else { return }

        if let badge = newBadges.sorted(by: { $0.tier.xp > $1.tier.xp }).first {
            celebration = Celebration(
                emoji: "🏅",
                title: badge.title,
                message: badge.detail,
                shareHeadline: "Just earned \(badge.title)"
            )
            return
        }

        let today = calendar.startOfDay(for: now)
        let alreadyCelebratedToday = celebratedGoalDay.map { calendar.isDate($0, inSameDayAs: today) } ?? false

        if health.today.metGoal(goal), !alreadyCelebratedToday {
            celebratedGoalDay = today

            if streak.isMilestone(streak.current), streak.current > celebratedStreakMilestone {
                celebratedStreakMilestone = streak.current
                celebration = Celebration(
                    emoji: "🔥",
                    title: "\(streak.current)-day streak",
                    message: "That's \(streak.current) days in a row hitting your goal.",
                    shareHeadline: "\(streak.current) days in a row"
                )
            } else {
                celebration = Celebration(
                    emoji: "🎯",
                    title: "Goal complete",
                    message: "\(health.today.steps.grouped) steps today. Streak: \(streak.current) day\(streak.current == 1 ? "" : "s").",
                    shareHeadline: "\(health.today.steps.grouped) steps today"
                )
            }
        }
    }

    // MARK: Cloud sync

    /// Pushes our daily totals up and pulls everyone else's down.
    ///
    /// Throttled, because Health fires an observer callback every time a batch
    /// of samples lands — which on an active morning is a lot more often than
    /// anyone needs a leaderboard refreshed.
    func syncCrews(history: [DailyActivity], force: Bool = false) async {
        let cloudCrews = crews.filter(\.isCloudBacked)
        guard !cloudCrews.isEmpty, !isSyncing else { return }

        if !force, let last = lastCloudSync, Date().timeIntervalSince(last) < 90 { return }

        isSyncing = true
        defer { isSyncing = false }

        cloudStatus = await cloud.availability()
        guard cloudStatus.isReady else { return }

        // Publishing first means the roster we pull back already reflects us.
        try? await cloud.publish(history: history, profile: profile, to: cloudCrews)

        for crew in cloudCrews {
            guard let bundle = try? await cloud.refresh(crew: crew, as: profile) else { continue }
            adopt(bundle)
        }

        lastCloudSync = Date()
        save()
    }

    // MARK: Leaderboards

    /// Today's standings inside one crew.
    ///
    /// Deliberately scoped to today: a rolling weekly total lets an early leader
    /// coast, whereas a board that resets every morning gives everyone a reason
    /// to walk today specifically.
    func todayLeaderboard(
        yourSteps: Int,
        crew: Crew,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [LeaderboardEntry] {
        let startOfDay = calendar.startOfDay(for: now)

        let rows: [(friend: Friend, steps: Int)] = crew.memberIDs.compactMap { id in
            guard let friend = roster[id] else { return nil }
            let steps = friend.isYou
                ? yourSteps
                : friend.steps(on: startOfDay, calendar: calendar, now: now)
            return (friend, steps)
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

    // MARK: Engine inputs

    /// Bundles everything `ChallengeEngine` needs from current state.
    func challengeInputs(
        health: HealthKitManager,
        goal: Int,
        useMetric: Bool = true,
        now: Date = Date()
    ) -> ChallengeEngine.Inputs {
        ChallengeEngine.Inputs(
            roster: roster,
            youID: profile.id,
            yourHistory: health.history,
            yourGoal: goal,
            useMetric: useMetric,
            now: now
        )
    }
}

// MARK: - Persistence

/// Tiny JSON-file store. Isolated behind a struct so tests and previews can
/// point at a scratch directory instead of the real one.
struct PersistenceStore {
    let url: URL?

    static func documents(filename: String = "stepcounting-state.json") -> PersistenceStore {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first

        guard let directory else { return PersistenceStore(url: nil) }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return PersistenceStore(url: directory.appendingPathComponent(filename))
    }

    /// An in-memory store that never touches disk — used by previews.
    static let ephemeral = PersistenceStore(url: nil)

    func read<T: Decodable>(_ type: T.Type) -> T? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    func write<T: Encodable>(_ value: T) {
        guard let url else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Previews

extension AppStore {
    /// A fully populated store backed by nothing on disk, for SwiftUI previews
    /// and demo builds.
    ///
    /// Runs a real `sync` against the sample Health data so the streak, badges,
    /// and XP shown are the ones those numbers genuinely produce — a mocked-up
    /// "14-day streak" that the engine wouldn't actually compute is how a demo
    /// ends up flattering a product that doesn't work.
    /// Default arguments are evaluated in a nonisolated context, so the health
    /// manager can't be defaulted here — hence the pair of overloads.
    static func preview() -> AppStore {
        preview(health: .preview())
    }

    static func preview(health: HealthKitManager) -> AppStore {
        let store = AppStore(cloud: DemoSocialService(), store: .ephemeral)
        store.completeOnboarding(name: "Sam", emoji: "⚡️", accentIndex: 1, joinSampleCrew: true)

        if let crew = store.crews.first {
            store.start(template: ChallengeTemplate.catalog[1], in: crew)   // 100K Week
            store.start(template: ChallengeTemplate.catalog[5], in: crew)   // Walk the Camino
        }

        store.sync(with: health, goal: 10_000)
        // Suppress the launch celebration; it would cover whatever we're showing.
        store.celebration = nil
        store.toast = nil
        return store
    }
}
