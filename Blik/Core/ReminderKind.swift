import CoreGraphics
import Foundation

enum ReminderKind: String, CaseIterable, Identifiable {
    case blink, posture, rest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blink: return "Blink"
        case .posture: return "Posture"
        case .rest: return "Rest"
        }
    }

    /// The word the toast spells out.
    var word: String { title.uppercased() }

    var detail: String {
        switch self {
        case .blink: return "A quick nudge to blink"
        case .posture: return "Sit tall, shoulders back"
        case .rest: return "Look away, eye gymnastics, water"
        }
    }

    var symbol: String {
        switch self {
        case .blink: return "eye"
        case .posture: return "figure.stand"
        case .rest: return "cup.and.saucer"
        }
    }

    var defaultMinutes: Int {
        switch self {
        case .blink: return 10
        case .posture: return 30
        case .rest: return 45
        }
    }

    var intervalOptions: [Int] {
        switch self {
        case .blink: return [1, 2, 3, 5, 10, 15, 20, 30]
        case .posture: return [5, 10, 15, 20, 30, 45, 60, 90]
        case .rest: return [15, 20, 30, 45, 60, 90, 120]
        }
    }

    /// How long the reminder stays on screen, in seconds.
    var duration: TimeInterval {
        switch self {
        case .blink: return 5
        case .posture: return 1
        case .rest: return RestTimeline.total
        }
    }

    var messages: [String] {
        switch self {
        case .blink:
            return [
                "Slow, full blinks. A few of them.",
                "Close your eyes. Breathe. Open.",
                "Your eyes are drying out. Blink.",
                "Ten blinks, nice and slow."
            ]
        case .posture:
            return [
                "Shoulders back. Chin level.",
                "Unfold. Sit tall. Feet flat.",
                "Drop your shoulders. Long neck.",
                "Straighten up, then relax into it."
            ]
        case .rest:
            return ["Time for a proper break."]
        }
    }

    func randomMessage() -> String {
        messages.randomElement() ?? title
    }
}

/// Timing of the full-screen rest break, in seconds.
enum RestTimeline {
    static let lookAway: Double = 20
    static let gymnastics: Double = 26
    static let drink: Double = 6
    static let total: Double = lookAway + gymnastics + drink

    /// Where the dot is, relative to the centre of the screen, `u` seconds into the exercise.
    static func dotOffset(_ u: Double, ax: Double, ay: Double) -> CGPoint {
        let turn = 2 * Double.pi
        if u < 3 { return .zero }
        if u < 11 {
            return CGPoint(x: ax * sin(turn * (u - 3) / 4), y: 0)
        }
        if u < 19 {
            return CGPoint(x: 0, y: -ay * sin(turn * (u - 11) / 4))
        }
        if u < 25.5 {
            let v = u - 19
            let radius = smooth(v / 1.0) * smooth((6.5 - v) / 1.0)
            let angle = turn * v / 3.25
            return CGPoint(x: ax * 0.8 * radius * sin(angle), y: -ay * radius * cos(angle))
        }
        return .zero
    }
}
