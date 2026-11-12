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
        case .rest: return "Look away, water, stretch, something off-screen"
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

    /// The toast of a quick reminder: its word, in a pill that is open for 3 seconds (blink)
    /// or 1.5 (posture). A rest break has none; it has a screen of its own that stays until it
    /// is dismissed.
    var toast: ToastSpec? {
        switch self {
        case .blink: return ToastSpec(icon: .glyph(self), text: "blink.", open: 3, dims: true)
        case .posture: return ToastSpec(icon: .glyph(self), text: "posture.", open: 1.5, dims: true)
        case .rest: return nil
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
