import SwiftUI

/// What a rest break's card shows and does. Shared with the card's window, whose keys drive it.
@MainActor
final class RestCardModel: ObservableObject {
    let start = Date()
    /// Off-screen activities that have not been done today.
    let candidates: [String]

    @Published private(set) var activity: String?
    @Published private(set) var rerolledAt: Date?
    @Published private(set) var rerolls = 0

    private let onSnooze: () -> Void
    private let onDone: (String?) -> Void

    /// Keys are ignored until the dim has covered the screen, so typing that was already under
    /// way when the break began does not answer it by accident.
    static let keysWakeAt = NotchRestBackdrop.covers + 0.25

    /// `onDone` is called with the activity that was on the list, if there was one.
    init(candidates: [String], onSnooze: @escaping () -> Void, onDone: @escaping (String?) -> Void) {
        self.candidates = candidates
        self.onSnooze = onSnooze
        self.onDone = onDone
        activity = candidates.randomElement()
    }

    var canReroll: Bool { candidates.count > 1 }

    func snooze() {
        onSnooze()
    }

    func done() {
        onDone(activity)
    }

    /// Swaps the suggested activity for another one that is still open today.
    func reroll() {
        guard let next = candidates.filter({ $0 != activity }).randomElement() else { return }
        activity = next
        rerolledAt = Date()
        rerolls += 1
    }

    /// A key pressed while the card has the keyboard: enter is done, space rerolls, esc snoozes.
    func key(_ code: UInt16) {
        guard Date().timeIntervalSince(start) >= Self.keysWakeAt else { return }
        switch code {
        case 36, 76: done()
        case 49: reroll()
        case 53: snooze()
        default: break
        }
    }
}

/// The rest break's to-do list and its two buttons. Lives in its own small window on top of the
/// dim, the only part of a break that takes clicks and keys. It stays until it is answered.
struct RestCard: View {
    @ObservedObject var model: RestCardModel

    static let size = CGSize(width: 460, height: 380)

    @State private var settled = false

    var body: some View {
        // The clock only runs while something is being typed.
        TimelineView(.animation(paused: settled)) { timeline in
            RestCardFace(
                t: timeline.date.timeIntervalSince(model.start),
                activity: model.activity,
                activityT: model.rerolledAt.map { timeline.date.timeIntervalSince($0) },
                canReroll: model.canReroll,
                onReroll: model.reroll,
                onSnooze: model.snooze,
                onDone: model.done
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: model.rerolls) {
            settled = false
        }
        .task(id: model.rerolls) {
            // Long enough for the opening to finish, and for a rerolled activity to be typed.
            let wait = max(2, RestCardFace.settlesAt - Date().timeIntervalSince(model.start))
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            if !Task.isCancelled {
                settled = true
            }
        }
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
                PillButton(title: "snooze 5 min", key: "esc", prominent: false, action: onSnooze)
                PillButton(title: "done", key: "↵", prominent: true, action: onDone)
            }
            .opacity(smooth((t - Self.buttonsAt) / 0.5))
            .allowsHitTesting(t >= Self.buttonsAt)
        }
        .frame(width: 290, alignment: .leading)
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
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                    Text(verbatim: "space")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
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
    /// The key that does the same thing, shown as a hint.
    let key: String
    /// The filled one is the button you are expected to press.
    let prominent: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        let ink = prominent ? Color.black : Color.white.opacity(hovering ? 1 : 0.75)
        Button(action: action) {
            HStack(spacing: 8) {
                Text(verbatim: title)
                    .foregroundColor(ink)
                Text(verbatim: key)
                    .foregroundColor(ink.opacity(0.45))
            }
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .padding(.horizontal, 18)
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
