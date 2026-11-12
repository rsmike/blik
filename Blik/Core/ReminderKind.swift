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

    /// What a quick reminder types out.
    var typed: String { title.lowercased() + "." }

    /// How long the finished message of a quick reminder is held, in seconds. The only timing
    /// that differs between them: how a reminder arrives and leaves is the same for every kind.
    var messageTime: TimeInterval {
        switch self {
        case .blink: return 4
        case .posture: return 2
        case .rest: return 0
        }
    }

    /// When backspacing starts, counted from the first keystroke.
    var eraseAt: TimeInterval {
        TypedLine.typingDuration(typed) + messageTime
    }

    /// First keystroke to last backspace, plus a beat of bare cursor.
    var typedTime: TimeInterval {
        eraseAt + TypedLine.erasingDuration(typed) + 0.2
    }

    /// How long a quick reminder stays on screen, in seconds.
    /// A rest break has no length of its own: it stays until it is dismissed.
    var duration: TimeInterval {
        typedTime + 2 * NotchDrop.lead
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
