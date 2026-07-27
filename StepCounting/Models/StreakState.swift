import Foundation

/// Streak progress, including the freezes that keep one bad day from ending it.
///
/// A streak that snaps the first time someone gets the flu is a churn machine —
/// the day the number resets to zero is the day a lot of people stop opening the
/// app. Freezes are the standard fix: a small monthly allowance that absorbs a
/// missed day so the habit survives the setback.
struct StreakState: Codable, Equatable {
    var current: Int = 0
    var longest: Int = 0
    /// Most recent day that counted towards the streak.
    var lastCountedDay: Date?
    /// Unused freezes in the bank.
    var freezesAvailable: Int = 1
    /// Days a freeze has been spent on, so they're never double-charged.
    var frozenDays: [Date] = []
    /// Start-of-month for the last freeze grant, so grants happen once a month.
    var lastGrantMonth: Date?
    /// Total days the goal was actually met, across all history seen.
    var totalGoalDays: Int = 0

    static let maxFreezes = 3
    static let freezesPerMonth = 1

    /// Milestones worth a celebration and a share prompt.
    static let milestones = [3, 7, 14, 30, 50, 75, 100, 150, 200, 365]

    func isMilestone(_ value: Int) -> Bool {
        Self.milestones.contains(value)
    }

    /// The next milestone ahead — gives the dashboard something to point at.
    var nextMilestone: Int? {
        Self.milestones.first { $0 > current }
    }

    var daysToNextMilestone: Int? {
        nextMilestone.map { $0 - current }
    }
}

/// Why the streak is where it is — drives the dashboard's streak card copy.
enum StreakStatus: Equatable {
    /// Goal already met today; nothing at risk.
    case safe
    /// Streak is alive but today's goal isn't met yet.
    case atRisk(stepsRemaining: Int)
    /// Missed yesterday, but a freeze can still be spent to save it.
    case rescuable(freezesAvailable: Int)
    /// No streak running.
    case none

    var isAtRisk: Bool {
        if case .atRisk = self { return true }
        return false
    }
}
