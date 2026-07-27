import Foundation

/// Turns a challenge plus a roster into a leaderboard.
///
/// Pure functions only: the same inputs always produce the same standings, which
/// makes the whole competitive layer trivially previewable and testable.
enum ChallengeEngine {

    struct Inputs {
        var roster: [UUID: Friend]
        var youID: UUID
        var yourHistory: [DailyActivity]
        var yourGoal: Int
        var useMetric: Bool = true
        var now: Date = Date()
        var calendar: Calendar = .current
    }

    // MARK: Per-participant totals

    /// One participant's total in the challenge's own units.
    static func value(
        for participantID: UUID,
        in challenge: Challenge,
        inputs: Inputs
    ) -> Int {
        let calendar = inputs.calendar
        let start = calendar.startOfDay(for: challenge.startDate)
        // Never count past the end of the challenge, or past today.
        let cappedEnd = min(challenge.endDate, inputs.now)
        let end = calendar.startOfDay(for: cappedEnd)
        guard end >= start else { return 0 }

        if participantID == inputs.youID {
            return yourValue(in: challenge, from: start, to: end, inputs: inputs)
        }

        guard let friend = inputs.roster[participantID] else { return 0 }
        return friendValue(friend, in: challenge, from: start, to: end, inputs: inputs)
    }

    private static func yourValue(
        in challenge: Challenge,
        from start: Date,
        to end: Date,
        inputs: Inputs
    ) -> Int {
        let window = inputs.yourHistory.filter { $0.date >= start && $0.date <= end }

        switch challenge.metric {
        case .steps:
            return window.totalSteps
        case .distance:
            return Int(window.totalDistanceMeters.rounded())
        case .goalDays:
            return window.goalDays(inputs.yourGoal)
        }
    }

    private static func friendValue(
        _ friend: Friend,
        in challenge: Challenge,
        from start: Date,
        to end: Date,
        inputs: Inputs
    ) -> Int {
        let calendar = inputs.calendar
        var day = start
        var steps = 0
        var goalDays = 0

        while day <= end {
            let daySteps = friend.steps(on: day, calendar: calendar, now: inputs.now)
            steps += daySteps
            // Crew-mates' personal goals aren't visible, so a shared 10k bar is
            // the fairest stand-in for a streak duel.
            if daySteps >= 10_000 { goalDays += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        switch challenge.metric {
        case .steps:
            return steps
        case .distance:
            return Int((Double(steps) * Units.metersPerStep).rounded())
        case .goalDays:
            return goalDays
        }
    }

    // MARK: Standings

    static func standings(for challenge: Challenge, inputs: Inputs) -> [Standing] {
        let raw: [(id: UUID, value: Int)] = challenge.participantIDs.map { id in
            (id, value(for: id, in: challenge, inputs: inputs))
        }

        let leader = raw.map(\.value).max() ?? 0
        let sorted = raw.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            // Stable tiebreak so rows don't shuffle between refreshes.
            return lhs.id.uuidString < rhs.id.uuidString
        }

        return sorted.enumerated().map { index, entry in
            let identity = participant(entry.id, inputs: inputs)
            let denominator = challenge.target > 0 ? Double(challenge.target) : Double(max(leader, 1))
            return Standing(
                id: entry.id,
                name: identity.name,
                emoji: identity.emoji,
                accentIndex: identity.accentIndex,
                isYou: entry.id == inputs.youID,
                value: entry.value,
                rank: index + 1,
                progress: min(Double(entry.value) / denominator, 1)
            )
        }
    }

    /// Pooled progress for cooperative challenges.
    static func teamTotal(for challenge: Challenge, inputs: Inputs) -> (value: Int, progress: Double) {
        let total = challenge.participantIDs.reduce(0) { sum, id in
            sum + value(for: id, in: challenge, inputs: inputs)
        }
        guard challenge.target > 0 else { return (total, 0) }
        return (total, min(Double(total) / Double(challenge.target), 1))
    }

    /// Overall progress a card can show without knowing the format.
    static func headlineProgress(for challenge: Challenge, inputs: Inputs) -> Double {
        if challenge.format.isCooperative {
            return teamTotal(for: challenge, inputs: inputs).progress
        }
        return standings(for: challenge, inputs: inputs).first?.progress ?? 0
    }

    /// Where you sit, if you're taking part.
    static func yourStanding(in challenge: Challenge, inputs: Inputs) -> Standing? {
        standings(for: challenge, inputs: inputs).first { $0.isYou }
    }

    /// The winner, once a challenge is decided.
    ///
    /// Races can be won early — the first person past the target takes it even
    /// if someone else later walks further.
    static func winner(of challenge: Challenge, inputs: Inputs) -> Standing? {
        let table = standings(for: challenge, inputs: inputs)
        guard let leader = table.first else { return nil }

        switch challenge.format {
        case .race:
            return leader.value >= challenge.target ? leader : nil
        case .mostSteps, .streakDuel:
            return challenge.hasEnded(at: inputs.now) && leader.value > 0 ? leader : nil
        case .teamTotal:
            return nil
        }
    }

    /// Pace check: are you ahead of where you need to be to finish in time?
    ///
    /// Only meaningful for target-based formats — "most steps" has no finish line.
    static func paceMessage(for challenge: Challenge, inputs: Inputs) -> String? {
        guard challenge.target > 0, challenge.isActive(at: inputs.now) else { return nil }

        let calendar = inputs.calendar
        let totalDays = Double(challenge.dayLength(calendar: calendar))
        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: challenge.startDate),
            to: calendar.startOfDay(for: inputs.now)
        ).day ?? 0
        // Count today as a day in progress rather than a whole day banked.
        let elapsedDays = min(Double(elapsed) + Friend.dayCompletion(at: inputs.now, calendar: calendar), totalDays)
        guard elapsedDays > 0.15 else { return nil }

        let current: Int
        if challenge.format.isCooperative {
            current = teamTotal(for: challenge, inputs: inputs).value
        } else {
            guard let you = yourStanding(in: challenge, inputs: inputs) else { return nil }
            current = you.value
        }

        let expected = Double(challenge.target) * (elapsedDays / totalDays)
        guard expected > 0 else { return nil }

        let delta = Double(current) - expected
        let ratio = abs(delta) / expected

        if ratio < 0.05 { return "Dead on pace" }
        let amount = challenge.metric.format(Int(abs(delta).rounded()), metric: inputs.useMetric)
        return delta > 0 ? "\(amount) ahead of pace" : "\(amount) behind pace"
    }

    // MARK: Helpers

    private static func participant(
        _ id: UUID,
        inputs: Inputs
    ) -> (name: String, emoji: String, accentIndex: Int) {
        if let friend = inputs.roster[id] {
            return (friend.isYou ? "You" : friend.displayName, friend.avatarEmoji, friend.accentIndex)
        }
        return ("Unknown", "❓", 0)
    }
}
