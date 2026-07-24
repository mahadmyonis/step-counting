import SwiftUI

/// Shared `@AppStorage` keys so views stay in sync without a store object.
enum SettingsKeys {
    static let dailyGoal = "dailyStepGoal"
    static let useMetric = "useMetricUnits"
}

struct SettingsView: View {
    @EnvironmentObject private var health: HealthKitManager
    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000
    @AppStorage(SettingsKeys.useMetric) private var useMetric = true

    private let goalRange = 1_000...30_000
    private let goalStep = 500

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily Goal") {
                    Stepper(value: $dailyGoal, in: goalRange, step: goalStep) {
                        HStack {
                            Text("Step goal")
                            Spacer()
                            Text(dailyGoal.formatted())
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    ForEach([8_000, 10_000, 12_000, 15_000], id: \.self) { preset in
                        Button {
                            dailyGoal = preset
                        } label: {
                            HStack {
                                Text("\(preset.formatted()) steps")
                                Spacer()
                                if dailyGoal == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section("Units") {
                    Picker("Distance", selection: $useMetric) {
                        Text("Kilometers").tag(true)
                        Text("Miles").tag(false)
                    }
                }

                Section("Health Access") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(statusText)
                            .foregroundStyle(statusColor)
                    }
                    Button("Refresh Data") {
                        Task { await health.refreshAll() }
                    }
                    .disabled(health.isRefreshing)
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Step, distance, and energy data is read from Apple Health and never leaves your device.")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var statusText: String {
        switch health.authorizationStatus {
        case .authorized: return "Connected"
        case .denied: return "Denied"
        case .notDetermined: return "Not Set"
        case .unavailable: return "Unavailable"
        }
    }

    private var statusColor: Color {
        switch health.authorizationStatus {
        case .authorized: return .green
        case .denied: return .red
        default: return .secondary
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .environmentObject(HealthKitManager())
}
