import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var notifications: NotificationScheduler

    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000
    @AppStorage(SettingsKeys.useMetric) private var useMetric = true
    @AppStorage(SettingsKeys.remindersEnabled) private var remindersEnabled = true

    private let goalRange = 1_000...40_000
    private let goalStep = 250

    var body: some View {
        Form {
            goalSection
            unitsSection
            remindersSection
            streakSection
            healthSection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await notifications.refreshAuthorizationStatus() }
    }

    // MARK: Sections

    private var goalSection: some View {
        Section("Daily Goal") {
            Stepper(value: $dailyGoal, in: goalRange, step: goalStep) {
                HStack {
                    Text("Step goal")
                    Spacer()
                    Text(dailyGoal.grouped)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            ForEach(GoalPreset.all) { preset in
                Button {
                    dailyGoal = preset.value
                } label: {
                    HStack {
                        Text("\(preset.value.grouped) steps")
                        Text("· \(preset.label)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if dailyGoal == preset.value {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private var unitsSection: some View {
        Section("Units") {
            Picker("Distance", selection: $useMetric) {
                Text("Kilometers").tag(true)
                Text("Miles").tag(false)
            }
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle("Reminders", isOn: $remindersEnabled)
                .onChange(of: remindersEnabled) { _, enabled in
                    Task {
                        if enabled {
                            await notifications.requestAuthorization()
                        } else {
                            notifications.cancelAll()
                        }
                    }
                }

            if remindersEnabled && !notifications.isAuthorized {
                Button("Allow notifications") {
                    Task { await notifications.requestAuthorization() }
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Two at most, and only when something's at stake: an evening nudge when your goal is within reach, and a last call when a live streak isn't safe yet.")
        }
    }

    private var streakSection: some View {
        Section {
            HStack {
                Label("Current streak", systemImage: "flame.fill")
                    .foregroundStyle(Theme.flame)
                Spacer()
                Text("\(store.streak.current) days")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack {
                Label("Freezes banked", systemImage: "snowflake")
                    .foregroundStyle(Theme.sky)
                Spacer()
                Text("\(store.streak.freezesAvailable) of \(StreakState.maxFreezes)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } header: {
            Text("Streak")
        } footer: {
            Text("You earn one freeze a month, up to \(StreakState.maxFreezes). Spending one covers a single missed day so the run keeps going.")
        }
    }

    private var healthSection: some View {
        Section("Health Access") {
            HStack {
                Text("Status")
                Spacer()
                Text(statusText)
                    .foregroundStyle(statusColor)
            }

            if health.authorizationStatus == .notDetermined {
                Button("Connect Apple Health") {
                    Task {
                        await health.requestAuthorization()
                        await health.refreshAll()
                    }
                }
            }

            Button("Refresh Data") {
                Task { await health.refreshAll() }
            }
            .disabled(health.isRefreshing)

            if let last = health.lastRefreshedAt {
                HStack {
                    Text("Last updated")
                    Spacer()
                    Text(last.formatted(.dateTime.hour().minute()))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Health data is read on this device and never uploaded. When you join a crew, this phone publishes one number per day — your step total — to your own iCloud so crew-mates can see it. There is no account to create and no server of ours in between.")
        }
    }

    // MARK: Derived

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
        case .authorized: return Theme.mint
        case .denied: return Theme.coral
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
    NavigationStack {
        SettingsView()
            .environmentObject(HealthKitManager.preview())
            .environmentObject(AppStore.preview())
            .environmentObject(NotificationScheduler())
    }
}
