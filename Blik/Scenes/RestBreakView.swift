import SwiftUI

/// The dim behind a rest break: the drop falls from the notch and spreads into it, and it stays
/// until the break is dismissed. The list and buttons live in their own window (`RestCard`).
struct RestBreakView: View {
    let dimmed: Bool
    let isPrimary: Bool
    let anchor: NotchAnchor

    @State private var start = Date()
    @State private var settled = false

    var body: some View {
        // Once the drop has spread there is nothing left to animate.
        TimelineView(.animation(paused: settled)) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            ZStack {
                NotchRestBackdrop(anchor: anchor, isPrimary: isPrimary, t: t, veil: dimmed ? 0.8 : 0)
                if isPrimary && !dimmed {
                    // Without the dim there is still a soft pool of shade so the list stays readable.
                    RadialGradient(
                        colors: [Color.black.opacity(0.6), Color.clear],
                        center: .center,
                        startRadius: 60,
                        endRadius: 460
                    )
                    .opacity(smooth((t - NotchRestBackdrop.lands) / 0.8))
                }
            }
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(nanoseconds: UInt64((NotchRestBackdrop.covers + 0.5) * 1_000_000_000))
            if !Task.isCancelled {
                settled = true
            }
        }
    }
}
