import Foundation

/// What a notch toast says: an icon, the word it types, and how long its pill stays open.
/// How a toast arrives and leaves is the same for every one of them; only that time differs.
struct ToastSpec {
    enum Icon {
        /// The animated glyph of a reminder.
        case glyph(ReminderKind)
        /// An SF Symbol.
        case symbol(String)
    }

    var icon: Icon
    var text: String
    /// Seconds the pill stays open, all told: the word is typed, held, and backspaced.
    var open: TimeInterval
    /// Whether every display dims while the toast is up, so it is noticed on whichever one
    /// you are looking at. For reminders; a toast you asked for with a key does not need it.
    var dims = false

    /// A beat of bare cursor after the last backspace, before the pill closes.
    private static let beat = 0.2

    /// When backspacing starts, counted from the first keystroke: late enough to be done,
    /// beat included, as the pill closes, and never before the word has been typed.
    var eraseAt: TimeInterval {
        max(TypedLine.typingDuration(text), open - TypedLine.erasingDuration(text) - Self.beat)
    }

    /// How long the whole toast stays on screen, in seconds: the drop arrives, the pill is open,
    /// the drop leaves.
    var duration: TimeInterval {
        open + 2 * NotchDrop.lead
    }

    static let focusOn = ToastSpec(icon: .symbol("timer"), text: "focus on.", open: 2.4)
    static let focusOff = ToastSpec(icon: .symbol("checkmark"), text: "focus off.", open: 2.4)
}
