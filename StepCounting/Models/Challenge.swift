import Foundation
import SwiftUI

/// What a challenge measures.
enum ChallengeMetric: String, Codable, CaseIterable, Identifiable {
    case steps
    case distance
    case goalDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steps: return "Steps"
        case .distance: return "Distance"
        case .goalDays: return "Goal days"
        }
    }

    var symbol: String {
        switch self {
        case .steps: return "shoeprints.fill"
        case .distance: return "point.topleft.down.curvedto.point.bottomright.up"
        case .goalDays: return "checkmark.seal.fill"
        }
    }

    func format(_ value: Int, metric: Bool) -> String {
        switch self {
        case .steps:
            return value.grouped
        case .distance:
            return Units.shortDistance(meters: Double(value), metric: metric)
        case .goalDays:
            return value == 1 ? "1 day" : "\(value) days"
        }
    }
}

/// How a challenge is won.
enum ChallengeFormat: String, Codable, CaseIterable, Identifiable {
    /// First participant to reach the target wins.
    case race
    /// Highest total when the window closes.
    case mostSteps
    /// Everyone's totals pooled against one shared target.
    case teamTotal
    /// Most days hitting your personal goal.
    case streakDuel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .race: return "Race to target"
        case .mostSteps: return "Most steps"
        case .teamTotal: return "Team total"
        case .streakDuel: return "Streak duel"
        }
    }

    /// Fits a card chip on a small phone, where `title` truncates.
    var shortTitle: String {
        switch self {
        case .race: return "Race"
        case .mostSteps: return "Most steps"
        case .teamTotal: return "Team"
        case .streakDuel: return "Streak duel"
        }
    }

    var detail: String {
        switch self {
        case .race: return "First to the finish line wins."
        case .mostSteps: return "Highest total when time runs out."
        case .teamTotal: return "Everyone's steps pooled toward one target."
        case .streakDuel: return "Most days hitting your own goal wins."
        }
    }

    var symbol: String {
        switch self {
        case .race: return "flag.checkered"
        case .mostSteps: return "chart.bar.fill"
        case .teamTotal: return "person.3.fill"
        case .streakDuel: return "flame.fill"
        }
    }

    /// Team challenges show one shared bar; the rest show a ranked list.
    var isCooperative: Bool { self == .teamTotal }
}

/// A time-boxed competition between crew-mates.
struct Challenge: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var emoji: String = "🏁"
    var format: ChallengeFormat
    var metric: ChallengeMetric
    /// Steps, meters, or days depending on `metric`. Ignored by `.mostSteps`.
    var target: Int
    var startDate: Date
    var endDate: Date
    var crewID: UUID?
    var participantIDs: [UUID]
    var accentIndex: Int = 0
    var createdByID: UUID
    /// Set when a virtual route backs this challenge.
    var routeID: String?

    var tint: Color { Theme.accent(accentIndex) }

    var route: VirtualRoute? {
        routeID.flatMap { VirtualRoute.catalog[$0] }
    }

    func isActive(at date: Date = Date()) -> Bool {
        date >= startDate && date < endDate
    }

    func isUpcoming(at date: Date = Date()) -> Bool {
        date < startDate
    }

    func hasEnded(at date: Date = Date()) -> Bool {
        date >= endDate
    }

    func status(at date: Date = Date()) -> String {
        if isUpcoming(at: date) {
            return "Starts \(startDate.formatted(.dateTime.month(.abbreviated).day()))"
        }
        if hasEnded(at: date) { return "Finished" }
        return Date.countdown(to: endDate, from: date)
    }

    /// Days elapsed, capped at the challenge length — used to pace expectations.
    func dayLength(calendar: Calendar = .current) -> Int {
        max(1, calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
    }
}

/// One participant's position in a challenge.
struct Standing: Identifiable, Equatable {
    let id: UUID
    let name: String
    let emoji: String
    let accentIndex: Int
    let isYou: Bool
    /// In the challenge's metric units.
    let value: Int
    let rank: Int
    /// 0–1 against the target (or against the leader, when there's no target).
    let progress: Double

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

// MARK: - Templates

/// Ready-made challenges, so creating one is a single tap.
///
/// A blank "create challenge" form is where social features go to die — most
/// people won't invent a target. Templates carry the idea for them.
struct ChallengeTemplate: Identifiable {
    let id: String
    let title: String
    let emoji: String
    let blurb: String
    let format: ChallengeFormat
    let metric: ChallengeMetric
    let target: Int
    let days: Int
    let accentIndex: Int
    var routeID: String?

    func makeChallenge(
        crewID: UUID?,
        participantIDs: [UUID],
        createdByID: UUID,
        startingAt start: Date = Date(),
        calendar: Calendar = .current
    ) -> Challenge {
        let startOfDay = calendar.startOfDay(for: start)
        let end = calendar.date(byAdding: .day, value: days, to: startOfDay) ?? startOfDay
        return Challenge(
            title: title,
            emoji: emoji,
            format: format,
            metric: metric,
            target: target,
            startDate: startOfDay,
            endDate: end,
            crewID: crewID,
            participantIDs: participantIDs,
            accentIndex: accentIndex,
            createdByID: createdByID,
            routeID: routeID
        )
    }

    static let catalog: [ChallengeTemplate] = [
        ChallengeTemplate(
            id: "weekend-warrior",
            title: "Weekend Warrior",
            emoji: "⚡️",
            blurb: "Two days. Whoever moves most takes it.",
            format: .mostSteps,
            metric: .steps,
            target: 0,
            days: 2,
            accentIndex: 4
        ),
        ChallengeTemplate(
            id: "hundred-k-week",
            title: "100K Week",
            emoji: "💯",
            blurb: "First to 100,000 steps in seven days.",
            format: .race,
            metric: .steps,
            target: 100_000,
            days: 7,
            accentIndex: 0
        ),
        ChallengeTemplate(
            id: "marathon-month",
            title: "Marathon Month",
            emoji: "🏅",
            blurb: "Cover 42.2 km on foot before the month is out.",
            format: .race,
            metric: .distance,
            target: 42_195,
            days: 30,
            accentIndex: 5
        ),
        ChallengeTemplate(
            id: "million-step-march",
            title: "Million Step March",
            emoji: "🚀",
            blurb: "Your whole crew, one million steps, thirty days.",
            format: .teamTotal,
            metric: .steps,
            target: 1_000_000,
            days: 30,
            accentIndex: 1
        ),
        ChallengeTemplate(
            id: "perfect-week",
            title: "Perfect Week",
            emoji: "🎯",
            blurb: "Hit your goal every single day. Most days wins.",
            format: .streakDuel,
            metric: .goalDays,
            target: 7,
            days: 7,
            accentIndex: 3
        ),
        ChallengeTemplate(
            id: "camino",
            title: "Walk the Camino",
            emoji: "🐚",
            blurb: "Retrace 780 km of the Camino Francés together.",
            format: .teamTotal,
            metric: .distance,
            target: 780_000,
            days: 60,
            accentIndex: 6,
            routeID: "camino"
        ),
        ChallengeTemplate(
            id: "route-66",
            title: "Route 66",
            emoji: "🛣️",
            blurb: "Chicago to Santa Monica — 3,940 km as a crew.",
            format: .teamTotal,
            metric: .distance,
            target: 3_940_000,
            days: 90,
            accentIndex: 2,
            routeID: "route66"
        ),
        ChallengeTemplate(
            id: "everest",
            title: "Climb Everest",
            emoji: "🏔️",
            blurb: "Base camp to summit — the vertical way, in steps.",
            format: .race,
            metric: .steps,
            target: 200_000,
            days: 21,
            accentIndex: 2,
            routeID: "everest"
        )
    ]
}
