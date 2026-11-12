import Foundation

/// What a notch toast says: an icon, the word it types, and how long the finished word is held.
/// How a toast arrives and leaves is the same for every one of them; only the hold differs.
struct ToastSpec {
    enum Icon {
        /// The animated glyph of a reminder.
        case glyph(ReminderKind)
        /// An SF Symbol.
        case symbol(String)
    }

    var icon: Icon
    var text: String
    /// Seconds the finished word stays before it is backspaced.
    var hold: TimeInterval

    /// When backspacing starts, counted from the first keystroke.
    var eraseAt: TimeInterval {
        TypedLine.typingDuration(text) + hold
    }

    /// First keystroke to last backspace, plus a beat of bare cursor.
    var typedTime: TimeInterval {
        eraseAt + TypedLine.erasingDuration(text) + 0.2
    }

    /// How long the whole toast stays on screen, in seconds.
    var duration: TimeInterval {
        typedTime + 2 * NotchDrop.lead
    }

    static let focusOn = ToastSpec(icon: .symbol("timer"), text: "focus on.", hold: 1.5)
    static let focusOff = ToastSpec(icon: .symbol("checkmark"), text: "focus off.", hold: 1.5)
}
