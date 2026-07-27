import Foundation

/// The time window shown on the stats screen.
enum StatsRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case quarter = "90 Days"

    var id: String { rawValue }

    /// Number of days included in the range.
    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }

    /// How often to label the x-axis so ticks never collide.
    var axisStride: Int {
        switch self {
        case .week: return 1
        case .month: return 5
        case .quarter: return 15
        }
    }

    /// Bars get too thin past a month, so long ranges render as an area chart.
    var prefersAreaChart: Bool {
        self == .quarter
    }

    /// The longest window the app keeps in memory.
    static var maxDayCount: Int {
        allCases.map(\.dayCount).max() ?? 30
    }
}
