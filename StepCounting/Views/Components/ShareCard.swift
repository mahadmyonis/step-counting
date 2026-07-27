import SwiftUI

/// The image people post when something good happens.
///
/// This is the app's growth loop in one view. The invite code sits on the card
/// on purpose: a screenshot of a great day is only a brag, but a screenshot with
/// a joinable code is an invitation — and it's shared at the exact moment
/// someone feels best about the app.
struct ShareCard: View {
    let headline: String
    let subheadline: String
    let profile: UserProfile
    var streak: Int = 0
    var badgeTitle: String?
    var accent: Color = Theme.brand

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                AvatarView(emoji: profile.avatarEmoji, accentIndex: profile.accentIndex, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text("\(streak)")
                            .monospacedDigit()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.18), in: Capsule())
                }
            }

            Spacer(minLength: 24)

            if let badgeTitle {
                Text(badgeTitle.uppercased())
                    .font(.caption.weight(.black))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 6)
            }

            Text(headline)
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(2)

            Text(subheadline)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 2)

            Spacer(minLength: 24)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("WALK WITH ME")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.65))
                    Text(profile.inviteCode)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "figure.walk.circle.fill")
                        .font(.title3)
                    Text("StepCounting")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(28)
        .frame(width: 400, height: 500)
        .background {
            ZStack {
                LinearGradient(
                    colors: [accent, accent.opacity(0.55), Theme.violet.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 320)
                    .offset(x: 150, y: -170)
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 220)
                    .offset(x: -140, y: 190)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

/// Renders a share card into an `Image` for `ShareLink`.
@MainActor
enum ShareCardRenderer {
    static func image(for card: ShareCard) -> Image? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

/// A share button that renders the card lazily, only when tapped.
struct ShareCardButton: View {
    let card: ShareCard
    var label: String = "Share"

    var body: some View {
        if let image = ShareCardRenderer.image(for: card) {
            ShareLink(
                item: image,
                preview: SharePreview(card.headline, image: image)
            ) {
                Label(label, systemImage: "square.and.arrow.up")
            }
        }
    }
}

#Preview {
    ShareCard(
        headline: "18,240 steps",
        subheadline: "Best day in three weeks",
        profile: UserProfile(displayName: "Sam", avatarEmoji: "⚡️", accentIndex: 1, inviteCode: "K7X2QM"),
        streak: 14,
        badgeTitle: "Personal best"
    )
}
