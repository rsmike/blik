import SwiftUI

/// Keyboard theme: the screen dims, one word is typed in the centre, held, then backspaced away.
struct KeyboardScene: View {
    let kind: ReminderKind
    let dimmed: Bool
    let isPrimary: Bool
    let duration: Double

    @State private var start = Date()

    private var fade: Double { 0.7 * pace(duration) }
    private var text: String { kind.title.lowercased() + "." }

    /// When backspacing starts, timed to finish just before the veil starts to lift.
    /// A reminder too short to hold the word for a moment skips it and simply fades.
    private var eraseAt: Double? {
        let at = duration - 2 * fade - TypedLine.erasingDuration(text) - 0.25
        return at - TypedLine.typingDuration(text) >= 0.6 ? at : nil
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            let strength = envelope(t, 0, duration, fade: fade)
            ZStack {
                Color.black.opacity((dimmed ? 0.5 : 0) * strength)
                if isPrimary {
                    TypedLine(
                        text: text,
                        t: t - fade,
                        eraseAt: eraseAt,
                        font: .system(size: 28, weight: .medium, design: .monospaced)
                    )
                    .shadow(color: Color.black.opacity(0.55), radius: 12)
                    .shadow(color: Color.black.opacity(0.35), radius: 3)
                    .opacity(strength)
                }
            }
        }
        .ignoresSafeArea()
    }
}
