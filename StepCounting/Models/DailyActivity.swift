import Foundation

/// A single day's aggregated activity metrics.
struct DailyActivity: Identifiable, Equatable {
    /// Start of the day (midnight, in the current calendar).
    let date: Date
    let steps: Int
    /// Walking + running distance, in meters.
    let distanceMeters: Double
    /// Active energy burned, in kilocalories.
    let activeEnergyKcal: Double

    var id: Date { date }

    static func empty(for date: Date) -> DailyActivity {
        DailyActivity(date: date, steps: 0, distanceMeters: 0, activeEnergyKcal: 0)
    }
}

extension DailyActivity {
    /// Distance rendered in the user's preferred units.
    func distanceString(metric: Bool) -> String {
        if metric {
            let km = distanceMeters / 1000
            return String(format: "%.2f km", km)
        } else {
            let miles = distanceMeters / 1609.344
            return String(format: "%.2f mi", miles)
        }
    }
}
