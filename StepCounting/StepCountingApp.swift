import SwiftUI

@main
struct StepCountingApp: App {
    @StateObject private var health = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(health)
                .task {
                    await health.requestAuthorization()
                    await health.refreshAll()
                }
        }
    }
}
