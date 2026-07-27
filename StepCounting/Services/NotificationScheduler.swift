import Foundation
import UserNotifications

/// Local notifications that bring people back without wearing out their welcome.
///
/// Every reminder here is tied to something the user has actually got riding on
/// it — a streak about to break, a challenge closing, a goal within reach. There
/// is deliberately no generic "come back!" nudge; those are the ones that get an
/// app's notifications switched off for good.
@MainActor
final class NotificationScheduler: ObservableObject {

    @Published private(set) var isAuthorized = false

    private let center = UNUserNotificationCenter.current()

    private enum ID {
        static let goalNudge = "nudge.goal"
        static let streakAtRisk = "nudge.streak"
        static let challengeEnding = "nudge.challenge"
    }

    // MARK: Permission

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            isAuthorized = false
            return false
        }
    }

    // MARK: Scheduling

    /// Rebuilds the whole reminder set from current state.
    ///
    /// Cheaper and far less error-prone than trying to mutate individual pending
    /// requests: cancel everything we own, then re-add what's still true.
    func reschedule(
        stepsToday: Int,
        goal: Int,
        streak: Int,
        streakStatus: StreakStatus,
        endingChallenge: Challenge?,
        remindersEnabled: Bool
    ) async {
        center.removePendingNotificationRequests(
            withIdentifiers: [ID.goalNudge, ID.streakAtRisk, ID.challengeEnding]
        )

        guard remindersEnabled, isAuthorized else { return }

        scheduleGoalNudge(stepsToday: stepsToday, goal: goal)
        scheduleStreakReminder(streak: streak, status: streakStatus)
        scheduleChallengeReminder(endingChallenge)
    }

    func cancelAll() {
        center.removePendingNotificationRequests(
            withIdentifiers: [ID.goalNudge, ID.streakAtRisk, ID.challengeEnding]
        )
    }

    // MARK: Individual reminders

    /// Early-evening nudge, only when the goal is still reachable.
    ///
    /// Telling someone at 6pm that they need another 9,000 steps isn't
    /// motivating, it's discouraging — so this stays quiet unless they're
    /// genuinely close.
    private func scheduleGoalNudge(stepsToday: Int, goal: Int) {
        let remaining = goal - stepsToday
        guard goal > 0, remaining > 0, Double(stepsToday) / Double(goal) >= 0.55 else { return }

        let content = UNMutableNotificationContent()
        content.title = "So close"
        content.body = "\(remaining.grouped) steps to your goal — about a \(walkMinutes(for: remaining))-minute walk."
        content.sound = .default

        add(content, at: DateComponents(hour: 18, minute: 30), id: ID.goalNudge)
    }

    /// Last call before midnight when a live streak hasn't been secured.
    private func scheduleStreakReminder(streak: Int, status: StreakStatus) {
        guard streak > 0, status.isAtRisk else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(streak)-day streak on the line"
        content.body = streak >= 7
            ? "You've come too far to drop it tonight."
            : "A short walk keeps it alive."
        content.sound = .default

        add(content, at: DateComponents(hour: 20, minute: 30), id: ID.streakAtRisk)
    }

    /// Morning-of reminder for a challenge on its final day.
    ///
    /// `endDate` is the exclusive midnight *after* the last day, so the reminder
    /// is anchored to the day before it — firing on `endDate` itself would land
    /// after the challenge had already been decided.
    private func scheduleChallengeReminder(_ challenge: Challenge?) {
        guard let challenge else { return }

        let calendar = Calendar.current
        let finalDay = calendar.startOfDay(for: challenge.endDate.addingTimeInterval(-1))
        guard let fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: finalDay),
              fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(challenge.emoji) \(challenge.title) ends today"
        content.body = "Last chance to move up the board."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        center.add(UNNotificationRequest(identifier: ID.challengeEnding, content: content, trigger: trigger))
    }

    // MARK: Helpers

    private func add(_ content: UNMutableNotificationContent, at time: DateComponents, id: String) {
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Rough walking time, at a comfortable 110 steps a minute.
    private func walkMinutes(for steps: Int) -> Int {
        max(1, Int((Double(steps) / 110).rounded()))
    }
}
