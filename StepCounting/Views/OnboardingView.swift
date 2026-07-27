import SwiftUI

/// First-run flow.
///
/// Four screens, no account, no email. The one thing it insists on is finishing
/// with something already happening — a goal set, Health connected, and a crew
/// to walk against — because an app that opens onto an empty state on day one
/// doesn't get a day two.
struct OnboardingView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var notifications: NotificationScheduler

    @AppStorage(SettingsKeys.dailyGoal) private var dailyGoal = 10_000

    @State private var page = 0
    @State private var name = ""
    @State private var emoji = "🏃"
    @State private var accentIndex = 0
    @State private var joinSampleCrew = true

    private let pageCount = 4

    var body: some View {
        ZStack {
            AuroraBackground(tint: Theme.accent(accentIndex), secondary: Theme.violet)

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcome.tag(0)
                    identity.tag(1)
                    goal.tag(2)
                    connect.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                controls
            }
        }
    }

    // MARK: Pages

    private var welcome: some View {
        page(
            emoji: "👟",
            title: "Walking is better\nwith other people",
            body: "Set a goal, keep a streak, and race the people you actually know. No feed of strangers, no ads, no account."
        ) {
            VStack(spacing: 12) {
                highlight("flame.fill", "Streaks that survive a bad day", Theme.flame)
                highlight("flag.checkered", "Challenges and virtual routes", Theme.brand)
                highlight("person.2.fill", "Private crews, invite-only", Theme.mint)
                highlight("lock.fill", "Health data never leaves the device", Theme.violet)
            }
            .padding(.top, 8)
        }
    }

    private var identity: some View {
        page(
            emoji: emoji,
            title: "Who's walking?",
            body: "This is what your crew sees. Change it any time."
        ) {
            VStack(spacing: 18) {
                TextField("Your name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .glassCard(radius: 16, padding: 0)
                    .textInputAutocapitalization(.words)

                emojiGrid
                accentPicker
            }
        }
    }

    private var goal: some View {
        page(
            emoji: "🎯",
            title: "Pick a daily goal",
            body: "Start where you actually are — a goal you hit is worth more than one you admire."
        ) {
            VStack(spacing: 16) {
                Text(dailyGoal.grouped)
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                HStack(spacing: 10) {
                    ForEach(GoalPreset.all) { preset in
                        Button {
                            withAnimation(Theme.springy) { dailyGoal = preset.value }
                            Haptics.tap()
                        } label: {
                            VStack(spacing: 3) {
                                Text(preset.value.compact)
                                    .font(.headline)
                                    .monospacedDigit()
                                Text(preset.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(dailyGoal == preset.value
                                          ? Theme.accent(accentIndex).opacity(0.22)
                                          : Color.primary.opacity(0.05))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        dailyGoal == preset.value ? Theme.accent(accentIndex) : .clear,
                                        lineWidth: 1.5
                                    )
                            }
                        }
                        .buttonStyle(.pressable)
                        .foregroundStyle(.primary)
                    }
                }

                Stepper("Fine-tune", value: $dailyGoal, in: 1_000...40_000, step: 250)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .glassCard(radius: 14, padding: 0)
            }
        }
    }

    private var connect: some View {
        page(
            emoji: "🤝",
            title: "One last thing",
            body: "Health access powers every number in the app. Everything else is optional."
        ) {
            VStack(spacing: 12) {
                permissionRow(
                    symbol: "heart.fill",
                    title: "Apple Health",
                    detail: healthDetail,
                    tint: Theme.coral,
                    isDone: health.authorizationStatus == .authorized
                ) {
                    Task {
                        await health.requestAuthorization()
                        await health.refreshAll()
                    }
                }

                permissionRow(
                    symbol: "bell.fill",
                    title: "Streak reminders",
                    detail: notifications.isAuthorized
                        ? "On — only when something's at stake"
                        : "A nudge when your streak is on the line",
                    tint: Theme.flame,
                    isDone: notifications.isAuthorized
                ) {
                    Task { await notifications.requestAuthorization() }
                }

                Toggle(isOn: $joinSampleCrew) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start with a sample crew")
                            .font(.subheadline.weight(.semibold))
                        Text("Four demo walkers so the leaderboards aren't empty. Leave any time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Theme.accent(accentIndex))
                .glassCard(radius: 16)
            }
        }
    }

    // MARK: Chrome

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Theme.accent(accentIndex) : Color.primary.opacity(0.15))
                        .frame(width: index == page ? 22 : 7, height: 7)
                        .animation(Theme.springy, value: page)
                }
            }

            Button {
                advance()
            } label: {
                Text(page == pageCount - 1 ? "Start walking" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent(accentIndex))
            .buttonBorderShape(.roundedRectangle(radius: 16))

            if page < pageCount - 1 {
                Button("Skip") { withAnimation(Theme.springy) { page = pageCount - 1 } }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Color.clear.frame(height: 20)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private func advance() {
        Haptics.tap()
        if page < pageCount - 1 {
            withAnimation(Theme.springy) { page += 1 }
        } else {
            store.completeOnboarding(
                name: name,
                emoji: emoji,
                accentIndex: accentIndex,
                joinSampleCrew: joinSampleCrew
            )
            store.sync(with: health, goal: dailyGoal)
        }
    }

    // MARK: Building blocks

    private func page<Content: View>(
        emoji: String,
        title: String,
        body: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 64))
                    .padding(.top, 40)

                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                content()
                    .padding(.top, 10)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }

    private func highlight(_ symbol: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.16), in: Circle())
            Text(text)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
    }

    private var emojiGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
            ForEach(UserProfile.avatarChoices, id: \.self) { choice in
                Button {
                    withAnimation(Theme.springy) { emoji = choice }
                    Haptics.tap()
                } label: {
                    Text(choice)
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle().fill(emoji == choice
                                          ? Theme.accent(accentIndex).opacity(0.25)
                                          : Color.primary.opacity(0.05))
                        }
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private var accentPicker: some View {
        HStack(spacing: 10) {
            ForEach(Theme.accents.indices, id: \.self) { index in
                Button {
                    withAnimation(Theme.springy) { accentIndex = index }
                    Haptics.tap()
                } label: {
                    Circle()
                        .fill(Theme.accent(index))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle()
                                .strokeBorder(.white, lineWidth: accentIndex == index ? 3 : 0)
                        }
                        .shadow(color: Theme.accent(index).opacity(0.5), radius: accentIndex == index ? 6 : 0)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private func permissionRow(
        symbol: String,
        title: String,
        detail: String,
        tint: Color,
        isDone: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.mint)
            } else {
                Button("Allow", action: action)
                    .font(.caption.weight(.bold))
                    .buttonStyle(.bordered)
                    .tint(tint)
            }
        }
        .glassCard(radius: 16)
    }

    private var healthDetail: String {
        switch health.authorizationStatus {
        case .authorized: return "Connected"
        case .denied: return "Denied — enable in Settings → Health → Data Access"
        case .unavailable: return "Not available on this device"
        case .notDetermined: return "Steps, distance, energy, and stairs"
        }
    }

}

/// Starting points that suit different people, so the goal step isn't a
/// number-entry field nobody knows how to answer.
struct GoalPreset: Identifiable {
    let value: Int
    let label: String

    var id: Int { value }

    static let all = [
        GoalPreset(value: 6_000, label: "Easing in"),
        GoalPreset(value: 8_000, label: "Steady"),
        GoalPreset(value: 10_000, label: "Classic"),
        GoalPreset(value: 12_500, label: "Ambitious")
    ]
}

#Preview {
    OnboardingView()
        .environmentObject(HealthKitManager.preview())
        .environmentObject(AppStore(social: LocalSocialService(), store: .ephemeral))
        .environmentObject(NotificationScheduler())
}
