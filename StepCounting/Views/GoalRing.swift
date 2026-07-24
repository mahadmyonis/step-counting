import SwiftUI

/// A circular progress ring showing steps against the daily goal.
struct GoalRing: View {
    let steps: Int
    let goal: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1)
    }

    private var goalReached: Bool { steps >= goal && goal > 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 22)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    goalReached ? AnyShapeStyle(Color.green.gradient) : AnyShapeStyle(Color.accentColor.gradient),
                    style: StrokeStyle(lineWidth: 22, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)

            VStack(spacing: 4) {
                Text(steps, format: .number)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("steps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if goal > 0 {
                    Text(goalReached ? "Goal reached 🎉" : "Goal \(goal.formatted())")
                        .font(.caption)
                        .foregroundStyle(goalReached ? .green : .secondary)
                        .padding(.top, 2)
                }
            }
        }
        .frame(width: 240, height: 240)
        .padding(8)
    }
}

#Preview {
    VStack(spacing: 40) {
        GoalRing(steps: 6200, goal: 10000)
        GoalRing(steps: 10500, goal: 10000)
    }
    .padding()
}
