import SwiftUI

struct RootView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var notifications: NotificationScheduler

    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000
    @AppStorage(SettingsKeys.remindersEnabled) private var remindersEnabled = true

    @Environment(\.scenePhase) private var scenePhase

    @State private var tab: RootTab = DemoMode.initialTab

    var body: some View {
        Group {
            if store.hasOnboarded {
                main
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .fontDesign(.rounded)
        .animation(Theme.gentle, value: store.hasOnboarded)
    }

    private var main: some View {
        TabView(selection: $tab) {
            DashboardView()
                .tabItem { Label("Today", systemImage: "figure.walk") }
                .tag(RootTab.today)

            ChallengesView()
                .tabItem { Label("Challenges", systemImage: "flag.checkered") }
                .tag(RootTab.challenges)

            CrewsView()
                .tabItem { Label("Crews", systemImage: "person.2.fill") }
                .tag(RootTab.crews)

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(RootTab.stats)

            ProfileView()
                .tabItem { Label("You", systemImage: "person.crop.circle") }
                .tag(RootTab.you)
        }
        // Every derived value — streak, badges, XP, challenge results — is
        // recomputed the moment Health hands us new numbers, so nothing in the
        // UI can be showing yesterday's answer.
        .onChange(of: health.lastRefreshedAt) { _, _ in
            store.sync(with: health, goal: dailyGoal)
            Task { await rescheduleReminders() }
        }
        .onChange(of: dailyGoal) { _, _ in
            store.sync(with: health, goal: dailyGoal)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await health.refreshAll()
                // An iCloud sign-in or sign-out only shows up on foreground.
                await store.refreshCloudStatus()
            }
        }
        .overlay(alignment: .top) { toast }
        .fullScreenCover(item: $store.celebration) { celebration in
            CelebrationOverlay(
                celebration: celebration,
                onDismiss: { store.celebration = nil }
            )
            .presentationBackground(.clear)
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let message = store.toast {
            Text(message)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .card(radius: 16, padding: 0)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: message) {
                    try? await Task.sleep(nanoseconds: 2_600_000_000)
                    withAnimation(Theme.springy) { store.toast = nil }
                }
        }
    }

    /// Rebuilds notifications around whatever is currently at stake.
    private func rescheduleReminders() async {
        let status = StreakEngine.status(
            store.streak,
            today: health.today,
            goal: dailyGoal,
            history: health.history
        )
        let endingToday = store.activeChallenges.first {
            Calendar.current.isDateInToday($0.endDate) || Calendar.current.isDateInTomorrow($0.endDate)
        }

        await notifications.reschedule(
            stepsToday: health.today.steps,
            goal: dailyGoal,
            streak: store.streak.current,
            streakStatus: status,
            endingChallenge: endingToday,
            remindersEnabled: remindersEnabled
        )
    }
}

#Preview {
    RootView()
        .environmentObject(HealthKitManager.preview())
        .environmentObject(AppStore.preview())
        .environmentObject(NotificationScheduler())
}
