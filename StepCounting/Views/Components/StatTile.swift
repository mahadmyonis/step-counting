import SwiftUI

/// A compact metric card used across the dashboard and stats screens.
struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = Theme.brand
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let footnote {
                    Text(footnote)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.top, 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// Round emoji avatar with a tinted halo. Used everywhere a person appears.
struct AvatarView: View {
    let emoji: String
    var accentIndex: Int = 0
    var size: CGFloat = 40
    var isYou: Bool = false

    private var tint: Color { Theme.accent(accentIndex) }

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(Theme.fill(tint).opacity(0.28))
            }
            .overlay {
                Circle()
                    .strokeBorder(isYou ? tint : tint.opacity(0.35), lineWidth: isYou ? 2 : 1)
            }
    }
}

/// Horizontal bar with a value label, used for standings and route progress.
struct ProgressBarRow: View {
    var progress: Double
    var tint: Color = Theme.brand
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.16))
                Capsule()
                    .fill(Theme.fill(tint))
                    .frame(width: max(height, geo.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                StatTile(title: "Distance", value: "6.4 km", systemImage: "location.fill")
                StatTile(title: "Energy", value: "412 kcal", systemImage: "flame.fill",
                         tint: Theme.flame, footnote: "+18% vs avg")
            }
            HStack(spacing: 14) {
                AvatarView(emoji: "⚡️", accentIndex: 1, size: 48, isYou: true)
                AvatarView(emoji: "🐆", accentIndex: 3, size: 48)
                AvatarView(emoji: "🌊", accentIndex: 5, size: 48)
            }
            ProgressBarRow(progress: 0.62, tint: Theme.violet)
        }
        .padding()
    }
}
