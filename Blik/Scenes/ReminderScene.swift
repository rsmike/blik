import SwiftUI

/// Root view of one full-screen overlay window: the rest break, or a quick reminder.
/// Only the primary display gets the content; during a rest break the others dim along.
struct ReminderScene: View {
    let kind: ReminderKind
    let dimmed: Bool
    let isPrimary: Bool
    let anchor: NotchAnchor

    var body: some View {
        Group {
            if kind == .rest {
                RestBreakView(dimmed: dimmed, isPrimary: isPrimary, anchor: anchor)
            } else {
                NotchScene(kind: kind, anchor: anchor, isPrimary: isPrimary, duration: kind.duration)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
