import SwiftUI
import Charts

/// History and trends.
///
/// The chart is the thing people compare apps on, so it gets real care: goal
/// days are coloured differently, the goal line is always visible, and every
/// summary number is framed against the previous period rather than floating
/// on its own.
struct StatsView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var store: AppStore

    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000
    @AppStorage(SettingsKeys.useMetric) private var useMetric = true

    @State private var range: StatsRange = .week

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(tint: Theme.sky, secondary: Theme.brand)

                ScrollView {
                    VStack(spacing: Theme.sectionSpacing) {
                        picker
                        chartCard
                        summary
                        consistencyCard
                        bestDayCard
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .refreshable { await health.refreshAll() }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Sections

    private var picker: some View {
        Picker("Range", selection: $range) {
            ForEach(StatsRange.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(visibleDays.averageSteps.grouped)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("avg / day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let delta = averageDelta {
                    Pill(
                        text: delta.text,
                        systemImage: delta.isUp ? "arrow.up.right" : "arrow.down.right",
                        tint: delta.isUp ? Theme.mint : Theme.coral
                    )
                }
            }

            chart
            legend
        }
        .card()
    }

    /// Explains the chart's colours without writing on top of it.
    private var legend: some View {
        HStack(spacing: Theme.Space.lg) {
            legendItem(Theme.mint, "Goal met")
            legendItem(Theme.brand, "Below goal")

            HStack(spacing: 5) {
                Rectangle()
                    .fill(Theme.mint.opacity(0.7))
                    .frame(width: 12, height: 1.5)
                Text("Goal \(dailyGoal.grouped)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
    }

    private func legendItem(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(visibleDays) { day in
                if range.prefersAreaChart {
                    AreaMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Steps", day.steps)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.brand.opacity(0.55), Theme.brand.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                } else {
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Steps", day.steps)
                    )
                    .foregroundStyle(
                        day.metGoal(dailyGoal)
                            ? Theme.fill(Theme.mint)
                            : Theme.fill(Theme.brand)
                    )
                    .cornerRadius(5)
                }
            }

            if dailyGoal > 0 {
                // Unlabelled on purpose — an inline annotation sat on top of
                // whichever bar happened to be leftmost. The legend below the
                // chart carries the number instead.
                RuleMark(y: .value("Goal", dailyGoal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(Theme.mint.opacity(0.7))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: range.axisStride)) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                AxisValueLabel {
                    if let steps = value.as(Int.self) {
                        Text(steps.compact).font(.caption2)
                    }
                }
            }
        }
        .frame(height: 220)
        .animation(Theme.gentle, value: range)
    }

    private var summary: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            StatTile(
                title: "Total steps",
                value: visibleDays.totalSteps.grouped,
                systemImage: "sum",
                tint: Theme.brand
            )
            StatTile(
                title: "Distance",
                value: Units.shortDistance(meters: visibleDays.totalDistanceMeters, metric: useMetric),
                systemImage: "location.fill",
                tint: Theme.sky
            )
            StatTile(
                title: "Active energy",
                value: "\(Int(visibleDays.totalEnergyKcal).grouped) kcal",
                systemImage: "flame.fill",
                tint: Theme.flame
            )
            StatTile(
                title: "Flights",
                value: visibleDays.reduce(0) { $0 + $1.flightsClimbed }.grouped,
                systemImage: "stairs",
                tint: Theme.violet
            )
        }
    }

    /// Goal days as a dot grid — a calendar-shaped view of consistency that
    /// reads faster than a percentage.
    private var consistencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Consistency",
                subtitle: "\(goalDays) of \(visibleDays.count) days at goal"
            ) {
                Text("\(consistencyPercent)%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.mint)
                    .monospacedDigit()
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 15),
                spacing: 5
            ) {
                ForEach(visibleDays) { day in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(dotColor(for: day))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private var bestDayCard: some View {
        if let best = visibleDays.bestDay, best.steps > 0 {
            HStack(spacing: 14) {
                Text("🏆")
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Best day this \(range == .week ? "week" : "period")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(best.steps.grouped)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                    Text(best.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                ShareCardButton(
                    card: ShareCard(
                        headline: "\(best.steps.grouped) steps",
                        subheadline: "Best day of my \(range.rawValue.lowercased())",
                        profile: store.profile,
                        streak: store.streak.current,
                        accent: Theme.gold,
                        inviteCode: store.shareableInviteCode
                    ),
                    label: ""
                )
                .labelStyle(.iconOnly)
                .font(.title3)
            }
            .card(tint: Theme.gold)
        }
    }

    // MARK: Derived

    private var visibleDays: [DailyActivity] {
        Array(health.history.suffix(range.dayCount))
    }

    /// The window immediately before the visible one, for period-over-period.
    private var previousDays: [DailyActivity] {
        let history = health.history
        let end = history.count - range.dayCount
        guard end > 0 else { return [] }
        let start = max(0, end - range.dayCount)
        return Array(history[start..<end])
    }

    private var averageDelta: (text: String, isUp: Bool)? {
        let previous = previousDays.averageSteps
        guard previous > 0, !previousDays.isEmpty else { return nil }
        let current = visibleDays.averageSteps
        let change = Double(current - previous) / Double(previous) * 100
        guard abs(change) >= 1 else { return nil }
        return (String(format: "%.0f%%", abs(change)), change > 0)
    }

    private var goalDays: Int {
        visibleDays.goalDays(dailyGoal)
    }

    private var consistencyPercent: Int {
        guard !visibleDays.isEmpty else { return 0 }
        return Int((Double(goalDays) / Double(visibleDays.count) * 100).rounded())
    }

    private func dotColor(for day: DailyActivity) -> Color {
        if day.metGoal(dailyGoal) { return Theme.mint }
        let progress = day.progress(towards: dailyGoal)
        if progress >= 0.6 { return Theme.mint.opacity(0.45) }
        if progress > 0 { return Theme.brand.opacity(0.28) }
        return Color.primary.opacity(0.08)
    }
}

#Preview {
    StatsView()
        .environmentObject(HealthKitManager.preview())
        .environmentObject(AppStore.preview())
}
