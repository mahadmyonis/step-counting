import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var health: HealthKitManager
    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000
    @AppStorage(SettingsKeys.useMetric) private var useMetric = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    switch health.authorizationStatus {
                    case .authorized:
                        content
                    case .notDetermined:
                        InfoState(
                            systemImage: "heart.text.square",
                            title: "Connecting to Health",
                            message: "Grant access to your step data to see your activity."
                        )
                    case .denied:
                        InfoState(
                            systemImage: "hand.raised.slash",
                            title: "Health Access Denied",
                            message: "Enable step, distance, and energy access in Settings → Health → Data Access to use StepCounting."
                        )
                    case .unavailable:
                        InfoState(
                            systemImage: "exclamationmark.triangle",
                            title: "Health Unavailable",
                            message: "Health data isn't available on this device."
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .refreshable { await health.refreshAll() }
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
            GoalRing(steps: health.today.steps, goal: dailyGoal)

            HStack(spacing: 12) {
                StatTile(
                    title: "Distance",
                    value: health.today.distanceString(metric: useMetric),
                    systemImage: "location.fill"
                )
                StatTile(
                    title: "Active Energy",
                    value: "\(Int(health.today.activeEnergyKcal)) kcal",
                    systemImage: "flame.fill",
                    tint: .orange
                )
            }

            let remaining = max(dailyGoal - health.today.steps, 0)
            if remaining > 0 {
                Text("\(remaining.formatted()) steps to go")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A centered informational placeholder for empty / permission states.
struct InfoState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    DashboardView()
        .environmentObject(HealthKitManager())
}
