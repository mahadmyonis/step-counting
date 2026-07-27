import Foundation

/// Everything the app needs from "other people".
///
/// The app never talks to a network directly — screens talk to `AppStore`,
/// `AppStore` talks to a `SocialService`. `CloudKitSocialService` is the real
/// implementation; `DemoSocialService` backs the sample crew and needs no
/// account at all.
protocol SocialService: AnyObject {

    /// Whether this backend can be used right now.
    func availability() async -> SocialAvailability

    /// Create a crew owned by the local user, and get back a code to share.
    func createCrew(
        name: String,
        emoji: String,
        accentIndex: Int,
        owner: UserProfile
    ) async throws -> CrewBundle

    /// Resolve an invite code and join the crew behind it.
    func joinCrew(code: String, as profile: UserProfile) async throws -> CrewBundle

    /// Pull down the current roster and everyone's published totals.
    func refresh(crew: Crew, as profile: UserProfile) async throws -> CrewBundle

    /// Publish the local user's recent daily totals to every crew they're in.
    ///
    /// This is the half that makes the whole thing work: HealthKit is
    /// device-local, so each phone reads its own Health store and pushes one
    /// number per day. Nobody ever reads anyone else's Health data.
    func publish(history: [DailyActivity], profile: UserProfile, to crews: [Crew]) async throws

    /// Leave (or, if we own it, tear down) a crew.
    func leave(crew: Crew, as profile: UserProfile) async throws
}

/// A crew plus everyone in it.
struct CrewBundle {
    var crew: Crew
    var members: [Friend]
}

/// Whether a backend is usable, and if not, what to tell the user.
enum SocialAvailability: Equatable {
    case ready
    case unavailable(reason: String)

    var isReady: Bool { self == .ready }

    var reason: String? {
        if case .unavailable(let reason) = self { return reason }
        return nil
    }
}

enum SocialError: LocalizedError, Equatable {
    case invalidCode
    case unknownCode
    case alreadyJoined(String)
    case notSupported
    case iCloudUnavailable(String)
    case shareFailed

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "That invite code doesn't look right. Codes are 8 characters, like AB3K9XQ2."
        case .unknownCode:
            return "No crew found for that code. Check it with whoever sent it — codes change if the owner resets them."
        case .alreadyJoined(let name):
            return "You're already in \(name)."
        case .notSupported:
            return "That isn't available for this crew."
        case .iCloudUnavailable(let reason):
            return reason
        case .shareFailed:
            return "Couldn't set up sharing for this crew. Check your connection and try again."
        }
    }
}

// MARK: - Demo backend

/// Backs the sample crew shown during onboarding.
///
/// This exists so a brand-new user isn't staring at an empty leaderboard before
/// they've invited anyone — not as a stand-in for the real thing. It can't join
/// or publish, and every crew it produces is flagged `isSimulated` so the UI can
/// say plainly that these aren't real people.
final class DemoSocialService: SocialService {

    func availability() async -> SocialAvailability { .ready }

    func createCrew(
        name: String,
        emoji: String,
        accentIndex: Int,
        owner: UserProfile
    ) async throws -> CrewBundle {
        throw SocialError.notSupported
    }

    func joinCrew(code: String, as profile: UserProfile) async throws -> CrewBundle {
        throw SocialError.notSupported
    }

    func refresh(crew: Crew, as profile: UserProfile) async throws -> CrewBundle {
        CrewBundle(crew: crew, members: [])
    }

    func publish(history: [DailyActivity], profile: UserProfile, to crews: [Crew]) async throws {
        // The sample crew has nobody to publish to.
    }

    func leave(crew: Crew, as profile: UserProfile) async throws {}

    /// A sample crew for the onboarding flow.
    static func sampleCrew(owner: UserProfile) -> CrewBundle {
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
            members.append(
                Friend(
                    id: uuid(from: memberSeed),
                    displayName: name,
                    avatarEmoji: UserProfile.avatarChoices.randomElement(using: &rng) ?? "🏃",
                    accentIndex: Int.random(in: 0..<Theme.accents.count, using: &rng),
                    isYou: false,
                    seed: memberSeed,
                    averageSteps: Int.random(in: 4_500...15_500, using: &rng),
                    consistency: Double.random(in: 0.25...0.9, using: &rng),
                    isSimulated: true
                )
            )
        }

        return members
    }

    /// Builds a stable UUID from a seed so the sample crew keeps its identity.
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
}
