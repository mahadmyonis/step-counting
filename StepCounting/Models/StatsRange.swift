import Foundation

/// The time window shown on the history screen.
enum StatsRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }

    /// Number of days included in the range.
    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        }
    }
}
