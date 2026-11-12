import Foundation

/// A focus session: a countdown started and stopped with a hot key. While it runs the rest break
/// is held back (see `Scheduler`); blink and posture carry on as usual.
@MainActor
final class FocusSession: ObservableObject {
    static let shared = FocusSession()

    /// Whole seconds left while a session is running. Drives the countdown in the menu bar.
    @Published private(set) var remaining: Int?
    /// When the running session is due to end.
    private(set) var endsAt: Date?
    /// When the last session ended. Up to that moment the user is taken to have been at the computer.
    private(set) var endedAt: Date?

    private var clock: Task<Void, Never>?

    private init() {}

    var isActive: Bool { endsAt != nil }

    /// The countdown as the menu bar shows it: minutes and seconds.
    static func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func toggle() {
        if isActive {
            end()
        } else {
            start()
        }
    }

    /// Starts a session of the length chosen in the settings.
    func start() {
        guard !isActive else { return }
        let end = Date().addingTimeInterval(TimeInterval(AppSettings.shared.focusMinutes * 60))
        endsAt = end
        // A rest break that is on screen is put off like any other: it comes back when the session ends.
        if OverlayController.shared.isShowingRest {
            Scheduler.shared.restStillDue()
        }
        announce(.focusOn, chime: .on)
        clock = Task { [weak self] in
            await self?.run(until: end)
        }
    }

    /// Ends the session before its time is up.
    func end() {
        guard isActive else { return }
        finish(quietly: false)
    }

    private func finish(quietly: Bool) {
        clock?.cancel()
        clock = nil
        endsAt = nil
        remaining = nil
        endedAt = Date()
        if !quietly {
            announce(.focusOff, chime: .off)
        }
    }

    private func announce(_ toast: ToastSpec, chime: Chime) {
        chime.play()
        OverlayController.shared.show(toast)
        // Blink and posture keep going, just not on the heels of this toast.
        Scheduler.shared.holdQuickReminders(until: Date().addingTimeInterval(toast.duration + 20))
    }

    private func run(until end: Date) async {
        while !Task.isCancelled {
            let left = end.timeIntervalSinceNow
            if left <= 0 {
                // Long overdue means the Mac slept through the end: no fanfare for that.
                finish(quietly: left < -60)
                return
            }
            let shown = left.rounded(.up)
            remaining = Int(shown)
            // Wake just after the countdown is due to show the next second.
            let untilNext = left - (shown - 1)
            try? await Task.sleep(nanoseconds: UInt64((untilNext + 0.01) * 1_000_000_000))
        }
    }
}
