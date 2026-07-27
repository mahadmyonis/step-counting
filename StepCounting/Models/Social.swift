import Foundation
import SwiftUI

// MARK: - You

/// The local user's identity.
///
/// Name, avatar, and colour are published to the crews you join so people can
/// tell who's who. Nothing else about you is — least of all your Health data,
/// which never leaves this device.
struct UserProfile: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var displayName: String = "You"
    var avatarEmoji: String = "🏃"
    var accentIndex: Int = 0
    var joinedAt: Date = Date()
    /// Experience from steps, goal days, badges, and challenge wins.
    var xp: Int = 0
    var challengesWon: Int = 0

    static let avatarChoices = [
        "🏃", "🚶", "🥾", "⚡️", "🔥", "🌟", "🐆", "🦅",
        "🐢", "🚀", "🏔️", "🌊", "🦖", "🍀", "🎯", "👟"
    ]
}

// MARK: - Levels

/// Long-arc progression that survives a bad week.
///
/// Streaks punish a missed day; levels never go down. Having both means a
/// lapsed user still has something intact to come back to.
struct Level: Equatable {
    let index: Int
    let title: String
    let xpFloor: Int
    let xpCeiling: Int

    static let titles = [
        "Wanderer", "Stroller", "Pacer", "Rambler", "Trailblazer",
        "Pathfinder", "Roadrunner", "Marathoner", "Summiteer", "Legend"
    ]

    /// Cumulative XP needed to reach a level — quadratic, so early levels come
    /// fast and later ones stay meaningful.
    static func xpFloor(for level: Int) -> Int {
        250 * (level - 1) * (level - 1)
    }

    static func forXP(_ xp: Int) -> Level {
        let index = max(1, Int((Double(max(xp, 0)) / 250).squareRoot()) + 1)
        return Level(
            index: index,
            title: titles[min(index - 1, titles.count - 1)],
            xpFloor: xpFloor(for: index),
            xpCeiling: xpFloor(for: index + 1)
        )
    }

    func progress(xp: Int) -> Double {
        let span = xpCeiling - xpFloor
        guard span > 0 else { return 1 }
        return min(max(Double(xp - xpFloor) / Double(span), 0), 1)
    }
}

enum XP {
    static let perHundredSteps = 1
    static let goalDay = 100
    static let badge = 250
    static let challengeWin = 500

    static func fromSteps(_ steps: Int) -> Int {
        steps / 100 * perHundredSteps
    }
}

// MARK: - Crew-mates

/// Someone you walk with.
///
/// For real crew-mates, `reportedSteps` is filled from what their own device
/// published to CloudKit — their phone read their Health store, never ours.
///
/// The `seed`/`averageSteps`/`consistency` trio only drives the onboarding
/// sample crew: they describe a walking personality that produces a stable,
/// believable history. `isSimulated` gates that path, so a real person with no
/// data for a day reads as zero rather than as a plausible invention.
struct Friend: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var displayName: String
    var avatarEmoji: String
    var accentIndex: Int
    /// True for the local user's own row.
    var isYou: Bool = false
    /// Drives the deterministic history below.
    var seed: UInt64 = 0
    var averageSteps: Int = 8_000
    /// 0 = wildly variable day to day, 1 = metronome.
    var consistency: Double = 0.6
    /// Steps this person's own device published, keyed by day.
    var reportedSteps: [String: Int] = [:]
    /// True only for demo crew-mates. Real people never fall back to simulation —
    /// a day they haven't published is zero, not a plausible-looking guess.
    var isSimulated: Bool = true
    /// When their device last published. Drives the "updated 4m ago" caption.
    var lastPublishedAt: Date?

    var initials: String {
        let parts = displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var tint: Color { Theme.accent(accentIndex) }
}

extension Friend {
    /// Steps for a given day.
    ///
    /// Prefers server-reported values and falls back to the simulated history,
    /// so mixing real and simulated participants in one leaderboard just works.
    func steps(on day: Date, calendar: Calendar = .current, now: Date = Date()) -> Int {
        if let reported = reportedSteps[Self.dayKey(day, calendar: calendar)] {
            return reported
        }
        guard isSimulated else { return 0 }
        return simulatedSteps(on: day, calendar: calendar, now: now)
    }

    static func dayKey(_ day: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    /// A believable day for this walking personality.
    ///
    /// Weekends run higher, an occasional rest day runs near zero, and today is
    /// scaled by how much of the waking day has actually happened — otherwise
    /// every crew-mate would appear to have finished 11,000 steps by 7am.
    private func simulatedSteps(on day: Date, calendar: Calendar, now: Date) -> Int {
        let startOfDay = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: now)
        guard startOfDay <= today else { return 0 }

        let dayIndex = Int((startOfDay.timeIntervalSince1970 / 86_400).rounded())
        var rng = SeededGenerator(seed: seed &+ UInt64(bitPattern: Int64(dayIndex &* 2_654_435_761)))

        let weekday = calendar.component(.weekday, from: startOfDay)
        let weekendBoost = (weekday == 1 || weekday == 7) ? 1.18 : 1.0

        // Low consistency widens the day-to-day spread.
        let spread = (1 - consistency) * 0.75
        let jitter = Double.random(in: (1 - spread)...(1 + spread), using: &rng)

        // Everyone takes the odd rest day; flaky walkers take more of them.
        let restChance = 0.04 + (1 - consistency) * 0.12
        let isRestDay = Double.random(in: 0...1, using: &rng) < restChance
        let restFactor = isRestDay ? Double.random(in: 0.12...0.35, using: &rng) : 1.0

        var value = Double(averageSteps) * weekendBoost * jitter * restFactor

        if startOfDay == today {
            value *= Self.dayCompletion(at: now, calendar: calendar)
        }

        return max(0, Int(value.rounded()))
    }

    /// Fraction of a typical walking day completed by `now`.
    ///
    /// Modelled on waking hours (6am–10pm) rather than raw clock time so an
    /// early-morning leaderboard isn't dominated by whoever is in a later
    /// timezone.
    static func dayCompletion(at now: Date, calendar: Calendar = .current) -> Double {
        let hour = Double(calendar.component(.hour, from: now))
        let minute = Double(calendar.component(.minute, from: now)) / 60
        let clock = hour + minute

        let wakeHour = 6.0
        let sleepHour = 22.0
        guard clock > wakeHour else { return 0.02 }
        guard clock < sleepHour else { return 1.0 }

        let linear = (clock - wakeHour) / (sleepHour - wakeHour)
        // Ease the curve: commutes and lunch bunch steps around the middle.
        return min(1, max(0.02, linear * linear * (3 - 2 * linear)))
    }
}

// MARK: - Crews

/// A private group of friends who see each other's daily totals.
///
/// Research on fitness retention is consistent that competing with people you
/// actually know beats competing with strangers, so crews are small, invite-only,
/// and there is no global leaderboard anywhere in the app.
struct Crew: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var emoji: String = "👟"
    var accentIndex: Int = 0
    var inviteCode: String
    var createdAt: Date = Date()
    var memberIDs: [UUID] = []
    /// True when this crew's members are generated on-device rather than real.
    var isSimulated: Bool = true
    /// Set when the crew is backed by a shared CloudKit zone.
    var cloud: CloudReference?
    /// When we last pulled crew-mates' numbers down.
    var lastSyncedAt: Date?

    var tint: Color { Theme.accent(accentIndex) }

    var isCloudBacked: Bool { cloud != nil }

    /// Where a crew lives in CloudKit.
    ///
    /// A crew is one custom record zone. The person who created it owns the zone
    /// in their private database; everyone else sees the same zone through their
    /// shared database, which is why `ownerName` decides which database to talk
    /// to on any given device.
    struct CloudReference: Codable, Equatable {
        var zoneName: String
        /// `nil` when this device owns the zone.
        var ownerName: String?
        /// The capability URL participants accept to join.
        var shareURL: String?

        var isOwner: Bool { ownerName == nil }
    }

    static let emojiChoices = ["👟", "🔥", "⚡️", "🏔️", "🌊", "🌲", "🦌", "🐺", "☕️", "🎽", "🚦", "🌻"]
}

// MARK: - Feed

/// Something worth telling your crew about.
struct FeedEvent: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case goalHit
        case personalBest
        case streakMilestone
        case badgeUnlocked
        case challengeJoined
        case challengeWon
        case crewJoined

        var symbol: String {
            switch self {
            case .goalHit: return "target"
            case .personalBest: return "bolt.fill"
            case .streakMilestone: return "flame.fill"
            case .badgeUnlocked: return "rosette"
            case .challengeJoined: return "flag.fill"
            case .challengeWon: return "trophy.fill"
            case .crewJoined: return "person.2.fill"
            }
        }

        var tint: Color {
            switch self {
            case .goalHit: return Theme.mint
            case .personalBest: return Theme.sky
            case .streakMilestone: return Theme.flame
            case .badgeUnlocked: return Theme.violet
            case .challengeJoined: return Theme.brand
            case .challengeWon: return Theme.gold
            case .crewJoined: return Theme.brand
            }
        }
    }

    /// Deterministic key (e.g. `goal-<member>-2026-7-27`) so a generated event
    /// keeps its identity across refreshes and cheers can be stored against it.
    var id: String
    var date: Date
    var actorID: UUID
    var actorName: String
    var actorEmoji: String
    var accentIndex: Int
    var kind: Kind
    var message: String
    /// Cheering is the cheapest possible way to tell someone you noticed them,
    /// which is exactly why it works.
    var cheers: Int = 0
    var youCheered: Bool = false

    var tint: Color { Theme.accent(accentIndex) }
}

// MARK: - Leaderboards

struct LeaderboardEntry: Identifiable, Equatable {
    let id: UUID
    let name: String
    let emoji: String
    let accentIndex: Int
    let isYou: Bool
    let value: Int
    let rank: Int
    /// Progress towards the leader, 0–1. Drives the bar width.
    let share: Double

    var tint: Color { Theme.accent(accentIndex) }

    var medal: String? {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }
}
