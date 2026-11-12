import SwiftUI

/// What a rest break's card shows and does. Shared with the card's window, whose keys drive it.
@MainActor
final class RestCardModel: ObservableObject {
    let start = Date()
    /// Off-screen activities that have not been done today.
    let candidates: [String]

    @Published private(set) var activity: String?
    /// The suggested activity was turned down: it stays open for today, and "done" does not count it.
    @Published private(set) var declined = false
    /// When the activity line last changed, and how many times it has.
    @Published private(set) var changedAt: Date?
    @Published private(set) var changes = 0

    private let onSnooze: () -> Void
    private let onDone: (String?) -> Void

    /// Keys are ignored until the dim has covered the screen, so typing that was already under
    /// way when the break began does not answer it by accident.
    static let keysWakeAt = NotchRestBackdrop.covers + 0.25

    /// `onDone` is called with the activity that was done, if one was.
    init(candidates: [String], onSnooze: @escaping () -> Void, onDone: @escaping (String?) -> Void) {
        self.candidates = candidates
        self.onSnooze = onSnooze
        self.onDone = onDone
        activity = candidates.randomElement()
    }

    /// There is another activity to offer, or the one that was turned down can come back.
    var canReroll: Bool { candidates.count > 1 || declined }
    var canDecline: Bool { activity != nil && !declined }

    func snooze() {
        onSnooze()
    }

    func done() {
        onDone(declined ? nil : activity)
    }

    /// Swaps the suggested activity for another one that is still open today.
    /// After it was turned down, this brings an activity back.
    func reroll() {
        let others = candidates.filter { $0 != activity }
        guard let next = others.randomElement() ?? (declined ? activity : nil) else { return }
        activity = next
        declined = false
        lineChanged()
    }

    /// Takes the activity off this break's list without crossing it off the day.
    func decline() {
        guard canDecline else { return }
        declined = true
        lineChanged()
    }

    private func lineChanged() {
        changedAt = Date()
        changes += 1
    }

    /// A key pressed while the card has the keyboard.
    func key(_ code: UInt16) {
        guard Date().timeIntervalSince(start) >= Self.keysWakeAt else { return }
        switch code {
        case 36, 76: done()       // return, keypad enter
        case 53: snooze()         // esc
        case 49: reroll()         // space
        case 51, 117: decline()   // delete, forward delete
        default: break
        }
    }
}

/// The rest break's to-do list and its buttons. Lives in its own small window on top of the
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
                declined: model.declined,
                activityT: model.changedAt.map { timeline.date.timeIntervalSince($0) },
                canReroll: model.canReroll,
                onReroll: model.reroll,
                onDecline: model.decline,
                onSnooze: model.snooze,
                onDone: model.done
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: model.changes) {
            settled = false
        }
        .task(id: model.changes) {
            // Long enough for the opening to finish, and for a changed activity line to be typed.
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
    let declined: Bool
    /// Seconds since the activity line last changed, if it has.
    let activityT: Double?
    let canReroll: Bool
    let onReroll: () -> Void
    let onDecline: () -> Void
    let onSnooze: () -> Void
    let onDone: () -> Void

    static let title = "rest."
    static let fixed = ["look far away", "drink water", "stretch"]
    /// What the activity line says once the activity has been turned down.
    static let noActivity = "no activity"

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
                    let text = Self.entry(declined ? Self.noActivity : activity)
                    let typed = local > TypedLine.typingDuration(text)
                    ActivityRow(
                        canReroll: canReroll && typed,
                        canDecline: !declined && typed,
                        onReroll: onReroll,
                        onDecline: onDecline
                    ) {
                        line(text, local: local, size: 19)
                            .opacity(declined ? 0.45 : 1)
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

/// The suggested activity. Click it for a different one, or click the cross to turn it down.
struct ActivityRow<Label: View>: View {
    let canReroll: Bool
    let canDecline: Bool
    let onReroll: () -> Void
    let onDecline: () -> Void
    @ViewBuilder var label: Label

    @State private var overReroll = false
    @State private var overDecline = false

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onReroll) {
                HStack(spacing: 4) {
                    label
                    hint("arrow.triangle.2.circlepath", key: "space", lit: overReroll)
                        .opacity(canReroll ? 1 : 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(canReroll)
            .onHover { overReroll = $0 }
            .help("Click for another")

            Button(action: onDecline) {
                hint("xmark", key: "del", lit: overDecline)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(canDecline ? 1 : 0)
            .allowsHitTesting(canDecline)
            .onHover { overDecline = $0 }
            .help("Not this time")
        }
    }

    private func hint(_ symbol: String, key: String, lit: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(verbatim: key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundColor(.white)
        .opacity(lit ? 0.95 : 0.4)
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
