import SwiftUI

/// Custom challenge builder, for people who want something the templates don't
/// cover. Deliberately the secondary path — templates carry most of the traffic.
struct NewChallengeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKeys.useMetric) private var useMetric = true

    @State private var title = ""
    @State private var emoji = "🏁"
    @State private var format: ChallengeFormat = .mostSteps
    @State private var metric: ChallengeMetric = .steps
    @State private var target = 100_000
    @State private var days = 7
    @State private var crewID: UUID?
    @State private var accentIndex = 0

    /// `.mostSteps` has no finish line, so a target field would be meaningless.
    private var needsTarget: Bool { format != .mostSteps }

    var body: some View {
        NavigationStack {
            Form {
                Section("The basics") {
                    TextField("Name", text: $title)
                    emojiRow
                    Picker("Crew", selection: $crewID) {
                        ForEach(store.crews) { crew in
                            Text("\(crew.emoji) \(crew.name)").tag(Optional(crew.id))
                        }
                    }
                }

                Section {
                    Picker("Format", selection: $format) {
                        ForEach(ChallengeFormat.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Picker("Measured in", selection: $metric) {
                        ForEach(ChallengeMetric.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } footer: {
                    Text(format.detail)
                }

                if needsTarget {
                    Section("Target") {
                        Stepper(value: $target, in: targetRange, step: targetStep) {
                            HStack {
                                Text("Reach")
                                Spacer()
                                Text(metric.format(target, metric: useMetric))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Section("Length") {
                    Stepper(value: $days, in: 1...90) {
                        HStack {
                            Text("Runs for")
                            Spacer()
                            Text("\(days) day\(days == 1 ? "" : "s")")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Section("Colour") {
                    HStack(spacing: 12) {
                        ForEach(Theme.accents.indices, id: \.self) { index in
                            Button {
                                accentIndex = index
                            } label: {
                                Circle()
                                    .fill(Theme.accent(index))
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        Circle().strokeBorder(.white, lineWidth: accentIndex == index ? 3 : 0)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Custom challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(crewID == nil)
                }
            }
            .onAppear { crewID = crewID ?? store.crews.first?.id }
            .onChange(of: metric) { _, newValue in
                target = Self.defaultTarget(for: newValue)
            }
        }
    }

    private var emojiRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.emojiChoices, id: \.self) { choice in
                    Button {
                        emoji = choice
                    } label: {
                        Text(choice)
                            .font(.title3)
                            .frame(width: 38, height: 38)
                            .background {
                                Circle().fill(emoji == choice
                                              ? Theme.accent(accentIndex).opacity(0.25)
                                              : Color.primary.opacity(0.05))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Actions

    private func create() {
        guard let crewID, let crew = store.crews.first(where: { $0.id == crewID }) else { return }
        store.createChallenge(
            title: title,
            emoji: emoji,
            format: format,
            metric: metric,
            target: needsTarget ? target : 0,
            days: days,
            crew: crew,
            accentIndex: accentIndex
        )
        dismiss()
    }

    // MARK: Metric-aware inputs

    private var targetRange: ClosedRange<Int> {
        switch metric {
        case .steps: return 5_000...5_000_000
        case .distance: return 1_000...5_000_000
        case .goalDays: return 1...90
        }
    }

    private var targetStep: Int {
        switch metric {
        case .steps: return 5_000
        case .distance: return 1_000
        case .goalDays: return 1
        }
    }

    private static func defaultTarget(for metric: ChallengeMetric) -> Int {
        switch metric {
        case .steps: return 100_000
        case .distance: return 50_000
        case .goalDays: return 7
        }
    }

    private static let emojiChoices = [
        "🏁", "🔥", "⚡️", "🏆", "🎯", "🚀", "🏔️", "🌊",
        "🐆", "🦵", "☀️", "🌙", "💯", "🥇", "🧭", "🛤️"
    ]
}

#Preview {
    NewChallengeView()
        .environmentObject(AppStore.preview())
}
