import Foundation

/// A famous journey a crew "walks" by pooling their real-world movement.
///
/// Landmarks are stored as fractions of the whole route rather than absolute
/// distances, so the same route works whether the backing challenge counts
/// kilometres or steps — the challenge target defines the scale.
struct VirtualRoute: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let emoji: String
    let landmarks: [Landmark]

    struct Landmark: Identifiable, Equatable {
        let id: String
        let name: String
        let emoji: String
        /// Position along the route, 0–1.
        let fraction: Double
    }

    /// The next landmark ahead of the given progress, if any.
    func nextLandmark(after progress: Double) -> Landmark? {
        landmarks.first { $0.fraction > progress }
    }

    /// The most recent landmark reached.
    func lastReached(at progress: Double) -> Landmark? {
        landmarks.last { $0.fraction <= progress }
    }

    static let catalog: [String: VirtualRoute] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    static let all: [VirtualRoute] = [
        VirtualRoute(
            id: "camino",
            name: "Camino Francés",
            subtitle: "Saint-Jean-Pied-de-Port → Santiago de Compostela",
            emoji: "🐚",
            landmarks: [
                Landmark(id: "pyrenees", name: "Over the Pyrenees", emoji: "⛰️", fraction: 0.04),
                Landmark(id: "pamplona", name: "Pamplona", emoji: "🐂", fraction: 0.10),
                Landmark(id: "logrono", name: "Logroño", emoji: "🍇", fraction: 0.21),
                Landmark(id: "burgos", name: "Burgos", emoji: "⛪️", fraction: 0.36),
                Landmark(id: "leon", name: "León", emoji: "🌆", fraction: 0.55),
                Landmark(id: "cruz", name: "Cruz de Ferro", emoji: "✝️", fraction: 0.71),
                Landmark(id: "sarria", name: "Sarria", emoji: "🌿", fraction: 0.86),
                Landmark(id: "santiago", name: "Santiago de Compostela", emoji: "🏆", fraction: 1.0)
            ]
        ),
        VirtualRoute(
            id: "route66",
            name: "Route 66",
            subtitle: "Chicago → Santa Monica",
            emoji: "🛣️",
            landmarks: [
                Landmark(id: "springfield", name: "Springfield, IL", emoji: "🌽", fraction: 0.08),
                Landmark(id: "stlouis", name: "St. Louis", emoji: "🌉", fraction: 0.15),
                Landmark(id: "tulsa", name: "Tulsa", emoji: "🎸", fraction: 0.29),
                Landmark(id: "amarillo", name: "Amarillo", emoji: "🤠", fraction: 0.45),
                Landmark(id: "albuquerque", name: "Albuquerque", emoji: "🌵", fraction: 0.58),
                Landmark(id: "canyon", name: "Grand Canyon", emoji: "🏜️", fraction: 0.74),
                Landmark(id: "vegas", name: "Barstow", emoji: "🌤️", fraction: 0.90),
                Landmark(id: "santamonica", name: "Santa Monica Pier", emoji: "🌊", fraction: 1.0)
            ]
        ),
        VirtualRoute(
            id: "everest",
            name: "Everest Ascent",
            subtitle: "Base Camp → Summit",
            emoji: "🏔️",
            landmarks: [
                Landmark(id: "basecamp", name: "Base Camp", emoji: "⛺️", fraction: 0.05),
                Landmark(id: "khumbu", name: "Khumbu Icefall", emoji: "🧊", fraction: 0.24),
                Landmark(id: "camp2", name: "Camp II", emoji: "🎒", fraction: 0.42),
                Landmark(id: "lhotse", name: "Lhotse Face", emoji: "🧗", fraction: 0.60),
                Landmark(id: "southcol", name: "South Col", emoji: "🌬️", fraction: 0.78),
                Landmark(id: "hillary", name: "Hillary Step", emoji: "🪜", fraction: 0.92),
                Landmark(id: "summit", name: "Summit", emoji: "🚩", fraction: 1.0)
            ]
        )
    ]
}
