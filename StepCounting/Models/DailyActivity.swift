import Foundation

/// A single day's aggregated activity metrics.
struct DailyActivity: Identifiable, Equatable, Codable {
    /// Start of the day (midnight, in the current calendar).
    let date: Date
    let steps: Int
    /// Walking + running distance, in meters.
    let distanceMeters: Double
    /// Active energy burned, in kilocalories.
    let activeEnergyKcal: Double
    /// Flights of stairs climbed.
    var flightsClimbed: Int = 0
    /// Apple Health exercise minutes.
    var exerciseMinutes: Int = 0

    var id: Date { date }

    static func empty(for date: Date) -> DailyActivity {
        DailyActivity(date: date, steps: 0, distanceMeters: 0, activeEnergyKcal: 0)
    }
}

extension DailyActivity {
    /// Distance rendered in the user's preferred units.
    func distanceString(metric: Bool) -> String {
        Units.distance(meters: distanceMeters, metric: metric)
    }

    func metGoal(_ goal: Int) -> Bool {
        goal > 0 && steps >= goal
    }

    func progress(towards goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1)
    }
}

/// Steps bucketed by hour of the day, for today's activity curve.
struct HourlySteps: Identifiable, Equatable {
    /// 0–23, in the current calendar.
    let hour: Int
    let steps: Int

    var id: Int { hour }

    /// Label for the chart axis — "6a", "12p", "9p".
    var label: String {
        switch hour {
        case 0: return "12a"
        case 1..<12: return "\(hour)a"
        case 12: return "12p"
        default: return "\(hour - 12)p"
        }
    }
}

extension Array where Element == DailyActivity {
    var totalSteps: Int { reduce(0) { $0 + $1.steps } }

    var totalDistanceMeters: Double { reduce(0) { $0 + $1.distanceMeters } }

    var totalEnergyKcal: Double { reduce(0) { $0 + $1.activeEnergyKcal } }

    var averageSteps: Int {
        isEmpty ? 0 : totalSteps / count
    }

    var bestDay: DailyActivity? {
        self.max { $0.steps < $1.steps }
    }

    func goalDays(_ goal: Int) -> Int {
        filter { $0.metGoal(goal) }.count
    }

    /// Total steps within a date window, inclusive of both bounds' days.
    func steps(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        let lower = calendar.startOfDay(for: start)
        let upper = calendar.startOfDay(for: end)
        return filter { $0.date >= lower && $0.date <= upper }.totalSteps
    }

    /// Days matching the goal within a window — used by streak-style challenges.
    func goalDays(_ goal: Int, from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        let lower = calendar.startOfDay(for: start)
        let upper = calendar.startOfDay(for: end)
        return filter { $0.date >= lower && $0.date <= upper && $0.metGoal(goal) }.count
    }
}
