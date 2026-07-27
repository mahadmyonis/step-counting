import SwiftUI

@main
struct StepCountingApp: App {
    @StateObject private var health: HealthKitManager
    @StateObject private var store: AppStore
    @StateObject private var notifications = NotificationScheduler()

    init() {
        // Demo mode swaps in fabricated data before any view exists, so nothing
        // downstream needs to know which mode it's running in.
        if DemoMode.isEnabled {
            let previewHealth = HealthKitManager.preview()
            _health = StateObject(wrappedValue: previewHealth)
            _store = StateObject(wrappedValue: AppStore.preview(health: previewHealth))
        } else {
            _health = StateObject(wrappedValue: HealthKitManager())
            _store = StateObject(wrappedValue: AppStore())
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(health)
                .environmentObject(store)
                .environmentObject(notifications)
                .tint(Theme.brand)
                .task {
                    guard !DemoMode.isEnabled else { return }
                    await health.requestAuthorization()
                    await health.refreshAll()
                    await notifications.refreshAuthorizationStatus()
                    await store.refreshCloudStatus()
                }
        }
    }
}
