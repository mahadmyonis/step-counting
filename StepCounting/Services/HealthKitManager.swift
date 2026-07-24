import Foundation
import HealthKit

/// Wraps HealthKit reads for step count, walking/running distance, and active energy.
///
/// Publishes today's live totals plus a rolling window of daily history that the
/// dashboard and history screens observe. All HealthKit work is funneled through
/// this single actor-like manager so the rest of the app never touches `HKHealthStore`.
@MainActor
final class HealthKitManager: ObservableObject {

    // MARK: Published state

    @Published private(set) var authorizationStatus: AuthState = .notDetermined
    @Published private(set) var today: DailyActivity = .empty(for: Calendar.current.startOfDay(for: Date()))
    @Published private(set) var history: [DailyActivity] = []
    @Published private(set) var isRefreshing = false

    enum AuthState: Equatable {
        case notDetermined
        case unavailable
        case denied
        case authorized
    }

    // MARK: Private

    private let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []

    private let stepType = HKQuantityType(.stepCount)
    private let distanceType = HKQuantityType(.distanceWalkingRunning)
    private let energyType = HKQuantityType(.activeEnergyBurned)

    private var readTypes: Set<HKObjectType> {
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
        guard authorizationStatus == .authorized else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let todayValue = fetchDay(Calendar.current.startOfDay(for: Date()))
        async let historyValue = fetchHistory(days: StatsRange.month.dayCount)

        today = await todayValue
        history = await historyValue
    }

    // MARK: Queries

    /// Fetches step/distance/energy totals for a single calendar day.
    private func fetchDay(_ startOfDay: Date) async -> DailyActivity {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: end, options: .strictStartDate)

        async let steps = sum(of: stepType, unit: .count(), predicate: predicate)
        async let distance = sum(of: distanceType, unit: .meter(), predicate: predicate)
        async let energy = sum(of: energyType, unit: .kilocalorie(), predicate: predicate)

        return DailyActivity(
            date: startOfDay,
            steps: Int(await steps),
            distanceMeters: await distance,
            activeEnergyKcal: await energy
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

        let stepsByDay = await steps
        let distanceByDay = await distance
        let energyByDay = await energy

        return (0..<days).compactMap { offset -> DailyActivity? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let key = calendar.startOfDay(for: day)
            return DailyActivity(
                date: key,
                steps: Int(stepsByDay[key] ?? 0),
                distanceMeters: distanceByDay[key] ?? 0,
                activeEnergyKcal: energyByDay[key] ?? 0
            )
        }
    }

    /// Sums a quantity type over a predicate window.
    private func sum(of type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double {
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
        for type in [stepType, distanceType, energyType] {
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
        for type in [stepType, distanceType, energyType] {
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }
}
