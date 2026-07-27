import Foundation
import SwiftUI

/// A badge you can earn once.
///
/// Badges are the app's long tail: streaks reward yesterday, challenges reward
/// this week, and badges give someone six months in something still left to
/// chase. Every one is checkable from data already on the device.
struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tier: Tier
    let requirement: Requirement

    enum Tier: String, CaseIterable, Identifiable {
        case bronze, silver, gold, legendary

        var id: String { rawValue }

        var title: String { rawValue.capitalized }

        var tint: Color {
            switch self {
            case .bronze: return Color(red: 0.80, green: 0.53, blue: 0.35)
            case .silver: return Color(red: 0.68, green: 0.72, blue: 0.78)
            case .gold: return Theme.gold
            case .legendary: return Theme.violet
            }
        }

        var xp: Int {
            switch self {
            case .bronze: return 150
            case .silver: return 300
            case .gold: return 600
            case .legendary: return 1_200
            }
        }
    }

    enum Requirement: Equatable {
        case singleDaySteps(Int)
        case lifetimeSteps(Int)
        case bestStreak(Int)
        case goalDays(Int)
        case challengesWon(Int)
        case crewsJoined(Int)
        case flights(Int)
        case lifetimeDistanceMeters(Double)
        /// Goal reached before this hour of the day.
        case goalBefore(hour: Int)
        /// Steps recorded after this hour.
        case activeAfter(hour: Int, steps: Int)

        func progress(in context: AchievementContext) -> Double {
            switch self {
            case .singleDaySteps(let target):
                return ratio(context.bestDaySteps, target)
            case .lifetimeSteps(let target):
                return ratio(context.lifetimeSteps, target)
            case .bestStreak(let target):
                return ratio(context.longestStreak, target)
            case .goalDays(let target):
                return ratio(context.goalDays, target)
            case .challengesWon(let target):
                return ratio(context.challengesWon, target)
            case .crewsJoined(let target):
                return ratio(context.crewCount, target)
            case .flights(let target):
                return ratio(context.lifetimeFlights, target)
            case .lifetimeDistanceMeters(let target):
                guard target > 0 else { return 1 }
                return min(context.lifetimeDistanceMeters / target, 1)
            case .goalBefore(let hour):
                return context.earliestGoalHour.map { $0 < hour ? 1.0 : 0.0 } ?? 0
            case .activeAfter(let hour, let steps):
                return context.stepsAfterHour(hour) >= steps ? 1.0 : 0.0
            }
        }

        func isSatisfied(by context: AchievementContext) -> Bool {
            progress(in: context) >= 1
        }

        private func ratio(_ value: Int, _ target: Int) -> Double {
            guard target > 0 else { return 1 }
            return min(Double(value) / Double(target), 1)
        }
    }
}

/// Everything the badge rules need, computed once per refresh.
struct AchievementContext {
    var bestDaySteps: Int = 0
    var lifetimeSteps: Int = 0
    var lifetimeDistanceMeters: Double = 0
    var lifetimeFlights: Int = 0
    var longestStreak: Int = 0
    var goalDays: Int = 0
    var challengesWon: Int = 0
    var crewCount: Int = 0
    /// Hour at which today's goal was crossed, if it was.
    var earliestGoalHour: Int?
    /// Today's steps bucketed by hour.
    var hourly: [HourlySteps] = []

    func stepsAfterHour(_ hour: Int) -> Int {
        hourly.filter { $0.hour >= hour }.reduce(0) { $0 + $1.steps }
    }
}

extension Achievement {

    /// The full badge catalog, ordered roughly by how soon someone earns it.
    static let catalog: [Achievement] = [
        // Getting started
        Achievement(id: "first-steps", title: "First Steps", detail: "Record 1,000 steps in a day.",
                    symbol: "shoeprints.fill", tier: .bronze, requirement: .singleDaySteps(1_000)),
        Achievement(id: "five-k", title: "Warmed Up", detail: "Walk 5,000 steps in a day.",
                    symbol: "figure.walk", tier: .bronze, requirement: .singleDaySteps(5_000)),
        Achievement(id: "ten-k", title: "Five Figures", detail: "Walk 10,000 steps in a day.",
                    symbol: "10.circle.fill", tier: .silver, requirement: .singleDaySteps(10_000)),
        Achievement(id: "twenty-k", title: "Double Down", detail: "Walk 20,000 steps in a day.",
                    symbol: "20.circle.fill", tier: .gold, requirement: .singleDaySteps(20_000)),
        Achievement(id: "fifty-k", title: "Unstoppable", detail: "Walk 50,000 steps in a single day.",
                    symbol: "bolt.circle.fill", tier: .legendary, requirement: .singleDaySteps(50_000)),

        // Streaks
        Achievement(id: "streak-3", title: "Warming Up", detail: "Hit your goal 3 days running.",
                    symbol: "flame", tier: .bronze, requirement: .bestStreak(3)),
        Achievement(id: "streak-7", title: "Week Strong", detail: "A 7-day goal streak.",
                    symbol: "flame.fill", tier: .silver, requirement: .bestStreak(7)),
        Achievement(id: "streak-30", title: "Month of Motion", detail: "A 30-day goal streak.",
                    symbol: "calendar.badge.checkmark", tier: .gold, requirement: .bestStreak(30)),
        Achievement(id: "streak-100", title: "Century Streak", detail: "100 consecutive goal days.",
                    symbol: "crown.fill", tier: .legendary, requirement: .bestStreak(100)),

        // Consistency
        Achievement(id: "goal-10", title: "Regular", detail: "Hit your goal on 10 days.",
                    symbol: "checkmark.seal", tier: .bronze, requirement: .goalDays(10)),
        Achievement(id: "goal-50", title: "Committed", detail: "Hit your goal on 50 days.",
                    symbol: "checkmark.seal.fill", tier: .silver, requirement: .goalDays(50)),
        Achievement(id: "goal-200", title: "Relentless", detail: "Hit your goal on 200 days.",
                    symbol: "medal.fill", tier: .gold, requirement: .goalDays(200)),

        // Lifetime volume
        Achievement(id: "life-100k", title: "Six Figures", detail: "100,000 lifetime steps.",
                    symbol: "sum", tier: .bronze, requirement: .lifetimeSteps(100_000)),
        Achievement(id: "life-1m", title: "Millionaire", detail: "One million lifetime steps.",
                    symbol: "sparkles", tier: .gold, requirement: .lifetimeSteps(1_000_000)),
        Achievement(id: "life-5m", title: "Five Million Club", detail: "Five million lifetime steps.",
                    symbol: "star.circle.fill", tier: .legendary, requirement: .lifetimeSteps(5_000_000)),

        // Distance
        Achievement(id: "marathon", title: "Marathon", detail: "Cover 42.2 km on foot.",
                    symbol: "figure.run", tier: .silver, requirement: .lifetimeDistanceMeters(42_195)),
        Achievement(id: "dist-500", title: "Long Hauler", detail: "Cover 500 km on foot.",
                    symbol: "map.fill", tier: .gold, requirement: .lifetimeDistanceMeters(500_000)),

        // Vertical
        Achievement(id: "flights-100", title: "Stair Master", detail: "Climb 100 flights of stairs.",
                    symbol: "stairs", tier: .silver, requirement: .flights(100)),
        Achievement(id: "flights-1000", title: "Skyscraper", detail: "Climb 1,000 flights of stairs.",
                    symbol: "building.2.fill", tier: .gold, requirement: .flights(1_000)),

        // Timing
        Achievement(id: "early-bird", title: "Early Bird", detail: "Hit your goal before 9am.",
                    symbol: "sunrise.fill", tier: .gold, requirement: .goalBefore(hour: 9)),
        Achievement(id: "night-owl", title: "Night Owl", detail: "Take 3,000 steps after 10pm.",
                    symbol: "moon.stars.fill", tier: .silver, requirement: .activeAfter(hour: 22, steps: 3_000)),

        // Social
        Achievement(id: "crew-1", title: "Better Together", detail: "Join your first crew.",
                    symbol: "person.2.fill", tier: .bronze, requirement: .crewsJoined(1)),
        Achievement(id: "crew-3", title: "Social Walker", detail: "Be part of 3 crews.",
                    symbol: "person.3.fill", tier: .silver, requirement: .crewsJoined(3)),
        Achievement(id: "win-1", title: "First Blood", detail: "Win a challenge.",
                    symbol: "trophy.fill", tier: .silver, requirement: .challengesWon(1)),
        Achievement(id: "win-10", title: "Serial Winner", detail: "Win 10 challenges.",
                    symbol: "trophy.circle.fill", tier: .legendary, requirement: .challengesWon(10))
    ]

    static func byID(_ id: String) -> Achievement? {
        catalog.first { $0.id == id }
    }
}
