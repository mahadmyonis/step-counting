import Foundation

/// Everything the app needs from "other people".
///
/// This is the seam a real backend plugs into. The app never talks to a network
/// directly — screens talk to `AppStore`, `AppStore` talks to a `SocialService`,
/// and swapping `LocalSocialService` for a CloudKit or server implementation is
/// the whole migration.
protocol SocialService: AnyObject {
    /// Resolve an invite code to a crew and its roster.
    func crew(forInviteCode code: String) async throws -> CrewBundle

    /// Create a brand-new crew owned by the local user.
    func createCrew(name: String, emoji: String, accentIndex: Int, owner: UserProfile) async throws -> CrewBundle

    /// Push the local user's recent totals so crew-mates see fresh numbers.
    func publish(history: [DailyActivity], profile: UserProfile) async throws

    /// Refresh a crew's roster (no-op for locally generated crews).
    func refresh(crew: Crew, knownMembers: [Friend]) async throws -> [Friend]
}

/// A crew plus everyone in it.
struct CrewBundle {
    let crew: Crew
    let members: [Friend]
}

enum SocialError: LocalizedError, Equatable {
    case invalidCode
    case alreadyJoined(String)

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "That invite code doesn't look right. Codes are 6 characters, like AB3K9X."
        case .alreadyJoined(let name):
            return "You're already in \(name)."
        }
    }
}

// MARK: - On-device implementation

/// Generates crews and crew-mates on the device, with no network involved.
///
/// Because every crew is derived deterministically from its invite code, two
/// people who type the same code see the same crew name, the same members, and
/// the same step histories — the social loop is fully playable offline. The
/// numbers for other members are simulated, which the UI states plainly; when a
/// server exists, `Friend.reportedSteps` gets filled from it and nothing else in
/// the app has to change.
final class LocalSocialService: SocialService {

    func crew(forInviteCode code: String) async throws -> CrewBundle {
        let normalized = InviteCode.normalize(code)
        guard normalized.count >= 4 else { throw SocialError.invalidCode }

        let seed = normalized.stableSeed
        var rng = SeededGenerator(seed: seed)

        let crew = Crew(
            id: Self.uuid(from: seed),
            name: Self.crewName(using: &rng),
            emoji: Crew.emojiChoices.randomElement(using: &rng) ?? "👟",
            accentIndex: Int.random(in: 0..<Theme.accents.count, using: &rng),
            inviteCode: normalized,
            createdAt: Date().addingTimeInterval(-Double.random(in: 86_400...(86_400 * 40), using: &rng)),
            memberIDs: [],
            isSimulated: true
        )

        let members = Self.makeMembers(count: Int.random(in: 3...6, using: &rng), seed: seed)
        return CrewBundle(crew: crew, members: members)
    }

    func createCrew(name: String, emoji: String, accentIndex: Int, owner: UserProfile) async throws -> CrewBundle {
        let crew = Crew(
            name: name,
            emoji: emoji,
            accentIndex: accentIndex,
            inviteCode: InviteCode.generate(),
            memberIDs: [owner.id],
            isSimulated: false
        )
        return CrewBundle(crew: crew, members: [])
    }

    func publish(history: [DailyActivity], profile: UserProfile) async throws {
        // Nothing to publish without a backend — the local user's numbers are
        // already the source of truth on this device.
    }

    func refresh(crew: Crew, knownMembers: [Friend]) async throws -> [Friend] {
        knownMembers
    }

    // MARK: Generation

    /// A demo crew for the onboarding flow, so the social tab is never empty on
    /// day one. Clearly labelled in the UI as a sample.
    static func demoCrew(owner: UserProfile) -> CrewBundle {
        let seed = "SAMPLE".stableSeed
        let crew = Crew(
            id: uuid(from: seed),
            name: "Sample Crew",
            emoji: "🌟",
            accentIndex: 1,
            inviteCode: "SAMPLE",
            createdAt: Date().addingTimeInterval(-86_400 * 12),
            memberIDs: [owner.id],
            isSimulated: true
        )
        return CrewBundle(crew: crew, members: makeMembers(count: 4, seed: seed))
    }

    /// Builds a believable roster: a couple of heavy walkers, a couple of
    /// average ones, and someone erratic — a leaderboard where everyone walks
    /// the same amount isn't worth looking at.
    static func makeMembers(count: Int, seed: UInt64) -> [Friend] {
        var rng = SeededGenerator(seed: seed &+ 7)
        var used = Set<String>()
        var members: [Friend] = []

        for index in 0..<count {
            var name = firstNames.randomElement(using: &rng) ?? "Alex"
            var attempts = 0
            while used.contains(name) && attempts < 12 {
                name = firstNames.randomElement(using: &rng) ?? "Alex"
                attempts += 1
            }
            used.insert(name)

            let memberSeed = seed &+ UInt64(index &* 977 &+ 13)
            // Spread averages across the range so ranks actually move.
            let average = Int.random(in: 4_500...15_500, using: &rng)
            members.append(
                Friend(
                    id: uuid(from: memberSeed),
                    displayName: name,
                    avatarEmoji: UserProfile.avatarChoices.randomElement(using: &rng) ?? "🏃",
                    accentIndex: Int.random(in: 0..<Theme.accents.count, using: &rng),
                    isYou: false,
                    seed: memberSeed,
                    averageSteps: average,
                    consistency: Double.random(in: 0.25...0.9, using: &rng)
                )
            )
        }

        return members
    }

    private static func crewName(using rng: inout SeededGenerator) -> String {
        let adjective = adjectives.randomElement(using: &rng) ?? "Morning"
        let noun = nouns.randomElement(using: &rng) ?? "Walkers"
        return "\(adjective) \(noun)"
    }

    /// Builds a stable UUID from a seed so a code always maps to one identity.
    static func uuid(from seed: UInt64) -> UUID {
        var rng = SeededGenerator(seed: seed)
        var bytes = [UInt8]()
        bytes.reserveCapacity(16)
        while bytes.count < 16 {
            let chunk = rng.next()
            for shift in stride(from: 0, to: 64, by: 8) where bytes.count < 16 {
                bytes.append(UInt8(truncatingIfNeeded: chunk >> UInt64(shift)))
            }
        }
        // Stamp version 4 / variant bits so this is a well-formed UUID.
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        let tuple = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple)
    }

    private static let firstNames = [
        "Amara", "Bea", "Caleb", "Dana", "Eli", "Farrah", "Gus", "Hana",
        "Ivan", "Jules", "Kiran", "Lena", "Milo", "Nadia", "Omar", "Priya",
        "Quinn", "Rosa", "Sam", "Tariq", "Uma", "Vik", "Wren", "Xiomara",
        "Yusuf", "Zoe", "Ana", "Bo", "Cleo", "Dev", "Esme", "Finn"
    ]

    private static let adjectives = [
        "Morning", "Midnight", "Restless", "Steady", "Sunday", "Concrete",
        "Uphill", "Coastal", "Downtown", "Quiet", "Golden", "Northside"
    ]

    private static let nouns = [
        "Walkers", "Striders", "Ramblers", "Pacers", "Wanderers",
        "Commuters", "Crew", "Club", "Society", "Collective"
    ]
}
