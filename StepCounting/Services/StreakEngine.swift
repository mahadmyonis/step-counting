import Foundation

/// Streak arithmetic, kept as pure functions so it's easy to reason about.
enum StreakEngine {

    /// Recomputes the streak from history, honouring spent freezes.
    ///
    /// Today not being finished yet never breaks a streak — the run is measured
    /// from yesterday backwards until today's goal lands. Otherwise everyone
    /// would watch their streak read zero every morning.
    static func recompute(
        _ state: StreakState,
        history: [DailyActivity],
        goal: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StreakState {
        var updated = grantMonthlyFreezeIfDue(state, now: now, calendar: calendar)

        let byDay = Dictionary(
            history.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let frozen = Set(updated.frozenDays.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)

        func counts(_ day: Date) -> Bool {
            if frozen.contains(day) { return true }
            return byDay[day]?.metGoal(goal) ?? false
        }

        // Start from today if it's already done, otherwise from yesterday.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var cursor = counts(today) ? today : yesterday
        let mostRecentCountedDay: Date? = counts(cursor) ? cursor : nil

        var windowStreak = 0
        while counts(cursor) {
            windowStreak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        var streak = windowStreak

        // History is a rolling window, so a streak longer than the window can't
        // be seen in full. When it saturates, extend the value we already had by
        // however many days have been completed since the last recompute.
        if windowStreak >= history.count, history.count > 0,
           let previousDay = updated.lastCountedDay,
           let latest = mostRecentCountedDay {
            let elapsed = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: previousDay),
                to: latest
            ).day ?? 0
            streak = max(windowStreak, updated.current + max(0, elapsed))
        }

        updated.current = streak
        updated.longest = max(updated.longest, streak)
        if let latest = mostRecentCountedDay {
            updated.lastCountedDay = latest
        }
        updated.totalGoalDays = max(updated.totalGoalDays, history.goalDays(goal))
        return updated
    }

    /// One free freeze a month, banked up to a cap.
    ///
    /// The allowance is deliberately small: a freeze has to feel like a rescue,
    /// not a way to keep a streak alive without walking.
    static func grantMonthlyFreezeIfDue(
        _ state: StreakState,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StreakState {
        var updated = state
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let monthStart = calendar.date(from: components) else { return updated }

        if let last = updated.lastGrantMonth, calendar.startOfDay(for: last) >= monthStart {
            return updated
        }

        updated.freezesAvailable = min(
            StreakState.maxFreezes,
            updated.freezesAvailable + StreakState.freezesPerMonth
        )
        updated.lastGrantMonth = monthStart
        return updated
    }

    /// The day a freeze would rescue, if there is one.
    ///
    /// Only ever the single most recent miss — freezes can't be used to paper
    /// over a week away.
    static func rescuableDay(
        _ state: StreakState,
        history: [DailyActivity],
        goal: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard state.freezesAvailable > 0 else { return nil }

        let byDay = Dictionary(
            history.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let frozen = Set(state.frozenDays.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let dayBefore = calendar.date(byAdding: .day, value: -2, to: today) else { return nil }

        func counts(_ day: Date) -> Bool {
            frozen.contains(day) || (byDay[day]?.metGoal(goal) ?? false)
        }

        // Yesterday was missed, but the day before it kept a run going.
        guard !counts(yesterday), counts(dayBefore) else { return nil }
        return yesterday
    }

    /// Spends a freeze on a day, then recomputes.
    static func spendFreeze(
        on day: Date,
        state: StreakState,
        history: [DailyActivity],
        goal: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StreakState {
        var updated = state
        guard updated.freezesAvailable > 0 else { return updated }

        let normalized = calendar.startOfDay(for: day)
        guard !updated.frozenDays.contains(normalized) else { return updated }

        updated.freezesAvailable -= 1
        updated.frozenDays.append(normalized)
        // Keep the list from growing forever; only recent days matter.
        updated.frozenDays = updated.frozenDays
            .sorted()
            .suffix(StatsRange.maxDayCount)
            .map { $0 }

        return recompute(updated, history: history, goal: goal, now: now, calendar: calendar)
    }

    /// What the dashboard should say about the streak right now.
    static func status(
        _ state: StreakState,
        today: DailyActivity,
        goal: Int,
        history: [DailyActivity],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StreakStatus {
        if today.metGoal(goal) { return .safe }

        if state.current > 0 {
            return .atRisk(stepsRemaining: max(goal - today.steps, 0))
        }

        if rescuableDay(state, history: history, goal: goal, now: now, calendar: calendar) != nil {
            return .rescuable(freezesAvailable: state.freezesAvailable)
        }

        return .none
    }
}
