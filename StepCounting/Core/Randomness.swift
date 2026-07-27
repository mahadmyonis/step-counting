import Foundation

/// Deterministic PRNG (SplitMix64).
///
/// Every simulated value in the app — a crew-mate's step history, the confetti
/// spread, a generated invite code — is derived from a seed rather than
/// `Double.random`, so the same input always produces the same output. That
/// keeps the UI stable across launches and makes two devices that type the
/// same invite code agree on what the crew looks like.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension String {
    /// Stable 64-bit hash (FNV-1a). Unlike `hashValue` this survives launches.
    var stableSeed: UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

extension UUID {
    /// Stable 64-bit seed derived from the UUID's bytes.
    var stableSeed: UInt64 {
        uuidString.stableSeed
    }
}

enum InviteCode {
    /// Ambiguous characters (0/O, 1/I) are excluded so codes survive being read
    /// aloud or typed from a screenshot.
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate(length: Int = 6) -> String {
        String((0..<length).map { _ in alphabet.randomElement() ?? "A" })
    }

    /// Normalises user input so "step-42x" and "STEP42X" resolve to one crew.
    static func normalize(_ raw: String) -> String {
        raw.uppercased().filter { alphabet.contains($0) }
    }
}
