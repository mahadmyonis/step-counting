import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject private var health: HealthKitManager
    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000
    @State private var range: StatsRange = .week

    /// The slice of history matching the selected range, oldest to newest.
    private var visibleDays: [DailyActivity] {
        Array(health.history.suffix(range.dayCount))
    }

    private var averageSteps: Int {
        guard !visibleDays.isEmpty else { return 0 }
        let total = visibleDays.reduce(0) { $0 + $1.steps }
        return total / visibleDays.count
    }

    private var totalSteps: Int {
        visibleDays.reduce(0) { $0 + $1.steps }
    }

    private var bestDay: DailyActivity? {
        visibleDays.max { $0.steps < $1.steps }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Range", selection: $range) {
                        ForEach(StatsRange.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    chart

                    HStack(spacing: 12) {
                        StatTile(title: "Daily Avg", value: averageSteps.formatted(), systemImage: "chart.bar.fill")
                        StatTile(title: "Total", value: totalSteps.formatted(), systemImage: "sum")
                    }

                    if let best = bestDay, best.steps > 0 {
                        StatTile(
                            title: "Best Day (\(best.date.formatted(.dateTime.weekday(.wide).month().day())))",
                            value: best.steps.formatted(),
                            systemImage: "trophy.fill",
                            tint: .yellow
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("History")
            .refreshable { await health.refreshAll() }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(visibleDays) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Steps", day.steps)
                )
                .foregroundStyle(day.steps >= dailyGoal ? Color.green.gradient : Color.accentColor.gradient)
                .cornerRadius(4)
            }

            if dailyGoal > 0 {
                RuleMark(y: .value("Goal", dailyGoal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 5)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().day(), centered: true)
            }
        }
        .frame(height: 220)
        .padding(.vertical, 8)
    }
}

#Preview {
    HistoryView()
        .environmentObject(HealthKitManager())
}
