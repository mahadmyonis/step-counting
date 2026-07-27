import SwiftUI

@main
struct StepCountingApp: App {
    @StateObject private var health = HealthKitManager()
    @StateObject private var store = AppStore()
    @StateObject private var notifications = NotificationScheduler()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(health)
                .environmentObject(store)
                .environmentObject(notifications)
                .tint(Theme.brand)
                .task {
                    await health.requestAuthorization()
                    await health.refreshAll()
                    await notifications.refreshAuthorizationStatus()
                }
        }
    }
}
