import Foundation

extension Int {
    /// "8,420" — grouped, locale aware.
    var grouped: String {
        formatted(.number.grouping(.automatic))
    }

    /// "8.4k" / "1.2M" — for tight spaces like leaderboard rows and chart labels.
    var compact: String {
        let value = Double(self)
        switch abs(self) {
        case 1_000_000...:
            return String(format: "%.1fM", value / 1_000_000)
        case 10_000...:
            return "\(Int((value / 1_000).rounded()))k"
        case 1_000...:
            return String(format: "%.1fk", value / 1_000)
        default:
            return "\(self)"
        }
    }
}

enum Units {
    static func distance(meters: Double, metric: Bool) -> String {
        if metric {
            return String(format: "%.2f km", meters / 1_000)
        }
        return String(format: "%.2f mi", meters / 1_609.344)
    }

    static func shortDistance(meters: Double, metric: Bool) -> String {
        if metric {
            return String(format: "%.1f km", meters / 1_000)
        }
        return String(format: "%.1f mi", meters / 1_609.344)
    }

    static var distanceUnitLabel: String { "distance" }

    /// Rough conversion used when a challenge is measured in distance but only
    /// step counts are available for other participants.
    static let metersPerStep = 0.762
}

extension Date {
    /// "Mon", "Tue" — chart and leaderboard day labels.
    var weekdayShort: String {
        formatted(.dateTime.weekday(.abbreviated))
    }

    var monthDay: String {
        formatted(.dateTime.month(.abbreviated).day())
    }

    /// "3 days left" style copy for challenge cards.
    static func countdown(to end: Date, from now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: now, to: end).day ?? 0
        if days > 1 { return "\(days) days left" }
        if days == 1 { return "1 day left" }

        let hours = calendar.dateComponents([.hour], from: now, to: end).hour ?? 0
        if hours > 1 { return "\(hours) hours left" }
        if hours == 1 { return "1 hour left" }
        return now >= end ? "Finished" : "Ending soon"
    }
}
