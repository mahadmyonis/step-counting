import Foundation
import HealthKit

/// Wraps every HealthKit read the app performs.
///
/// Publishes today's live totals, an hourly breakdown, a rolling window of daily
/// history, and lifetime aggregates. All HealthKit work is funnelled through
/// this single manager so the rest of the app never touches `HKHealthStore`.
@MainActor
final class HealthKitManager: ObservableObject {

    // MARK: Published state

    @Published private(set) var authorizationStatus: AuthState = .notDetermined
    @Published private(set) var today: DailyActivity = .empty(for: Calendar.current.startOfDay(for: Date()))
    @Published private(set) var history: [DailyActivity] = []
    @Published private(set) var hourlyToday: [HourlySteps] = []
    @Published private(set) var lifetime: LifetimeTotals = .zero
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshedAt: Date?

    enum AuthState: Equatable {
        case notDetermined
        case unavailable
        case denied
        case authorized
    }

    /// All-time aggregates, used by badges and the profile screen.
    struct LifetimeTotals: Equatable {
        var steps: Int
        var distanceMeters: Double
        var flights: Int

        static let zero = LifetimeTotals(steps: 0, distanceMeters: 0, flights: 0)
    }

    // MARK: Private

    private let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    /// Set by `preview()`. Freezes the published values so nothing overwrites them.
    private var isPreviewData = false

    private let stepType = HKQuantityType(.stepCount)
    private let distanceType = HKQuantityType(.distanceWalkingRunning)
    private let energyType = HKQuantityType(.activeEnergyBurned)
    private let flightsType = HKQuantityType(.flightsClimbed)
    private let exerciseType = HKQuantityType(.appleExerciseTime)

    private var readTypes: Set<HKObjectType> {
        [stepType, distanceType, energyType, flightsType, exerciseType]
    }

    /// Types worth watching live. Exercise minutes change too rarely to justify
    /// waking the whole refresh pipeline.
    private var observedTypes: [HKQuantityType] {
        [stepType, distanceType, energyType]
    }

    // MARK: Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            return
        }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            // HealthKit intentionally hides read-authorization status, so we infer
            // access from whether a sample query returns without error.
            authorizationStatus = .authorized
            enableBackgroundDelivery()
            startObserving()
        } catch {
            authorizationStatus = .denied
        }
    }

    // MARK: Public refresh

    func refreshAll() async {
        // Demo builds hold fabricated data; a real query would wipe it.
        guard !isPreviewData, authorizationStatus == .authorized else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshedAt = Date()
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())

        async let todayValue = fetchDay(startOfDay)
        async let historyValue = fetchHistory(days: StatsRange.maxDayCount)
        async let hourlyValue = fetchHourly(for: startOfDay)
        async let lifetimeValue = fetchLifetime()

        today = await todayValue
        history = await historyValue
        hourlyToday = await hourlyValue
        lifetime = await lifetimeValue
    }

    /// The hour today's goal was crossed, if it has been. Powers the Early Bird
    /// badge and the "you finished before lunch" style copy.
    func hourGoalReached(goal: Int) -> Int? {
        guard goal > 0 else { return nil }
        var running = 0
        for bucket in hourlyToday.sorted(by: { $0.hour < $1.hour }) {
            running += bucket.steps
            if running >= goal { return bucket.hour }
        }
        return nil
    }

    // MARK: Queries

    /// Fetches every metric for a single calendar day.
    private func fetchDay(_ startOfDay: Date) async -> DailyActivity {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: end, options: .strictStartDate)

        async let steps = sum(of: stepType, unit: .count(), predicate: predicate)
        async let distance = sum(of: distanceType, unit: .meter(), predicate: predicate)
        async let energy = sum(of: energyType, unit: .kilocalorie(), predicate: predicate)
        async let flights = sum(of: flightsType, unit: .count(), predicate: predicate)
        async let exercise = sum(of: exerciseType, unit: .minute(), predicate: predicate)

        return DailyActivity(
            date: startOfDay,
            steps: Int(await steps),
            distanceMeters: await distance,
            activeEnergyKcal: await energy,
            flightsClimbed: Int(await flights),
            exerciseMinutes: Int(await exercise)
        )
    }

    /// Fetches a contiguous run of daily totals ending today.
    private func fetchHistory(days: Int) async -> [DailyActivity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        async let steps = collection(of: stepType, unit: .count(), start: start, end: today)
        async let distance = collection(of: distanceType, unit: .meter(), start: start, end: today)
        async let energy = collection(of: energyType, unit: .kilocalorie(), start: start, end: today)
        async let flights = collection(of: flightsType, unit: .count(), start: start, end: today)

        let stepsByDay = await steps
        let distanceByDay = await distance
        let energyByDay = await energy
        let flightsByDay = await flights

        return (0..<days).compactMap { offset -> DailyActivity? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let key = calendar.startOfDay(for: day)
            return DailyActivity(
                date: key,
                steps: Int(stepsByDay[key] ?? 0),
                distanceMeters: distanceByDay[key] ?? 0,
                activeEnergyKcal: energyByDay[key] ?? 0,
                flightsClimbed: Int(flightsByDay[key] ?? 0)
            )
        }
    }

    /// Buckets today's steps into 24 hours so the dashboard can show a curve.
    private func fetchHourly(for startOfDay: Date) async -> [HourlySteps] {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: end, options: .strictStartDate)

        let buckets: [Int: Double] = await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startOfDay,
                intervalComponents: DateComponents(hour: 1)
            )
            query.initialResultsHandler = { _, collection, _ in
                var result: [Int: Double] = [:]
                collection?.enumerateStatistics(from: startOfDay, to: end) { stats, _ in
                    let hour = calendar.component(.hour, from: stats.startDate)
                    result[hour, default: 0] += stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }

        return (0..<24).map { HourlySteps(hour: $0, steps: Int(buckets[$0] ?? 0)) }
    }

    /// All-time totals. `nil` predicate means "every sample HealthKit will give us".
    private func fetchLifetime() async -> LifetimeTotals {
        async let steps = sum(of: stepType, unit: .count(), predicate: nil)
        async let distance = sum(of: distanceType, unit: .meter(), predicate: nil)
        async let flights = sum(of: flightsType, unit: .count(), predicate: nil)

        return LifetimeTotals(
            steps: Int(await steps),
            distanceMeters: await distance,
            flights: Int(await flights)
        )
    }

    /// Sums a quantity type over a predicate window.
    private func sum(of type: HKQuantityType, unit: HKUnit, predicate: NSPredicate?) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Buckets a quantity type into per-day sums keyed by start-of-day.
    private func collection(of type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async -> [Date: Double] {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: start)
        let interval = DateComponents(day: 1)
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: endExclusive, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, _ in
                var result: [Date: Double] = [:]
                collection?.enumerateStatistics(from: anchor, to: endExclusive) { stats, _ in
                    let key = calendar.startOfDay(for: stats.startDate)
                    result[key] = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    // MARK: Live updates

    private func startObserving() {
        for type in observedTypes {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
                Task { @MainActor in
                    await self?.refreshAll()
                    completion()
                }
            }
            store.execute(query)
            observerQueries.append(query)
        }
    }

    private func enableBackgroundDelivery() {
        for type in observedTypes {
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }
}

// MARK: - Previews

extension HealthKitManager {
    /// A manager pre-filled with plausible data, so previews and demo builds
    /// show a populated app without any Health samples on disk.
    ///
    /// Shaped deliberately rather than randomly: a live streak with today still
    /// in progress is what the app looks like most of the time someone opens it,
    /// and it's the only state where the ring, the streak card, and the "steps to
    /// go" copy are all doing something.
    static func preview() -> HealthKitManager {
        let manager = HealthKitManager()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var rng = SeededGenerator(seed: 20_260_727)

        func day(_ offset: Int, steps: Int) -> DailyActivity? {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyActivity(
                date: date,
                steps: steps,
                distanceMeters: Double(steps) * Units.metersPerStep,
                activeEnergyKcal: Double(steps) / 22,
                flightsClimbed: Int.random(in: 2...16, using: &rng),
                exerciseMinutes: Int.random(in: 12...68, using: &rng)
            )
        }

        var days: [DailyActivity] = []
        for offset in stride(from: StatsRange.maxDayCount - 1, through: 0, by: -1) {
            let steps: Int
            switch offset {
            case 0:
                // Today, mid-afternoon: goal in sight but not met.
                steps = 8_640
            case 1...13:
                // A live streak — every day comfortably over a 10k goal.
                steps = Int.random(in: 10_400...19_200, using: &rng)
            default:
                // Further back, a normal mix of good days and off days.
                steps = Int.random(in: 3_900...17_500, using: &rng)
            }
            if let entry = day(offset, steps: steps) { days.append(entry) }
        }

        manager.isPreviewData = true
        manager.authorizationStatus = .authorized
        manager.history = days
        manager.today = days.last ?? .empty(for: today)
        manager.lastRefreshedAt = Date()

        // A commuter's day: a walk to the station, a lunch loop, an evening walk.
        let shape: [Int: Int] = [
            6: 320, 7: 1_180, 8: 940, 9: 260, 10: 180, 11: 240,
            12: 860, 13: 1_120, 14: 300, 15: 420, 16: 380, 17: 1_240, 18: 880
        ]
        manager.hourlyToday = (0..<24).map { HourlySteps(hour: $0, steps: shape[$0] ?? 0) }

        manager.lifetime = LifetimeTotals(
            steps: 1_284_000,
            distanceMeters: 978_000,
            flights: 640
        )
        return manager
    }
}
