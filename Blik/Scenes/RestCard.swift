import SwiftUI

/// The rest break's to-do list and its two buttons. Lives in its own small window on top of the
/// dim, the only part of a break that takes clicks. It stays until one of the buttons is pressed.
struct RestCard: View {
    /// Off-screen activities that have not been done today.
    let candidates: [String]
    let onSnooze: () -> Void
    /// Called with the activity that was on the list, if there was one.
    let onDone: (String?) -> Void

    static let size = CGSize(width: 460, height: 380)

    @State private var start = Date()
    @State private var activity: String?
    @State private var rerolledAt: Date?
    @State private var rerolls = 0
    @State private var settled = false

    init(candidates: [String], onSnooze: @escaping () -> Void, onDone: @escaping (String?) -> Void) {
        self.candidates = candidates
        self.onSnooze = onSnooze
        self.onDone = onDone
        _activity = State(initialValue: candidates.randomElement())
    }

    var body: some View {
        // The clock only runs while something is being typed.
        TimelineView(.animation(paused: settled)) { timeline in
            RestCardFace(
                t: timeline.date.timeIntervalSince(start),
                activity: activity,
                activityT: rerolledAt.map { timeline.date.timeIntervalSince($0) },
                canReroll: candidates.count > 1,
                onReroll: reroll,
                onSnooze: onSnooze,
                onDone: { onDone(activity) }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: rerolls) {
            // Long enough for the opening to finish, and for a rerolled activity to be typed.
            let wait = max(2, RestCardFace.settlesAt - Date().timeIntervalSince(start))
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            if !Task.isCancelled {
                settled = true
            }
        }
    }

    /// Swaps the suggested activity for another one that is still open today.
    private func reroll() {
        guard let next = candidates.filter({ $0 != activity }).randomElement() else { return }
        activity = next
        rerolledAt = Date()
        settled = false
        rerolls += 1
    }
}

/// One frame of the card, `t` seconds after the break began.
struct RestCardFace: View {
    let t: Double
    let activity: String?
    /// Seconds since the activity was swapped for another, if it has been.
    let activityT: Double?
    let canReroll: Bool
    let onReroll: () -> Void
    let onSnooze: () -> Void
    let onDone: () -> Void

    static let title = "rest."
    static let fixed = ["look far away", "drink water", "stretch"]

    /// The list starts typing once the drop has landed and begun to spread.
    static let opens = NotchRestBackdrop.lands + 0.4
    /// When each line starts typing: the title, the fixed lines, then the activity.
    static let starts: [Double] = {
        var at = opens
        var result: [Double] = []
        for text in [title] + fixed.map(entry) {
            result.append(at)
            at += TypedLine.typingDuration(text) + 0.15
        }
        result.append(at)
        return result
    }()
    /// The buttons are there from the start, so the break can be put off without waiting for the list.
    static let buttonsAt = opens
    static let settlesAt = starts[starts.count - 1] + 3

    static func entry(_ text: String) -> String {
        "- " + text.lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            line(Self.title, local: t - Self.starts[0], size: 30)
            VStack(alignment: .leading, spacing: 13) {
                ForEach(0..<Self.fixed.count, id: \.self) { index in
                    line(Self.entry(Self.fixed[index]), local: t - Self.starts[index + 1], size: 19)
                }
                if let activity = activity {
                    let local = activityT ?? t - Self.starts[Self.fixed.count + 1]
                    let text = Self.entry(activity)
                    RerollRow(
                        enabled: canReroll && local > TypedLine.typingDuration(text),
                        action: onReroll
                    ) {
                        line(text, local: local, size: 19)
                    }
                }
            }
            HStack(spacing: 12) {
                PillButton(title: "snooze 5 min", prominent: false, action: onSnooze)
                PillButton(title: "done", prominent: true, action: onDone)
            }
            .opacity(smooth((t - Self.buttonsAt) / 0.5))
            .allowsHitTesting(t >= Self.buttonsAt)
        }
        .frame(width: 250, alignment: .leading)
        .shadow(color: Color.black.opacity(0.5), radius: 10)
    }

    /// A line that types itself out. The cursor is only there while it is being typed.
    private func line(_ text: String, local: Double, size: CGFloat) -> some View {
        let typing = local >= 0 && local < TypedLine.typingDuration(text) + 0.35
        return TypedLine(
            text: text,
            t: local,
            font: .system(size: size, weight: .medium, design: .monospaced),
            cursor: typing ? "_" : " "
        )
    }
}

/// The suggested activity: click it for a different one.
struct RerollRow<Label: View>: View {
    let enabled: Bool
    let action: () -> Void
    @ViewBuilder var label: Label

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                label
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(enabled ? (hovering ? 0.95 : 0.4) : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(enabled)
        .onHover { hovering = $0 }
        .help("Click for another")
    }
}

struct PillButton: View {
    let title: String
    /// The filled one is the button you are expected to press.
    let prominent: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(prominent ? .black : Color.white.opacity(hovering ? 1 : 0.75))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(fill)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(prominent ? 0 : 0.25), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var fill: Double {
        if prominent {
            return hovering ? 1 : 0.86
        }
        return hovering ? 0.24 : 0.12
    }
}
