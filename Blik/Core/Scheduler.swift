import AppKit
import SwiftUI

/// Decides when each reminder fires. Ticks once a second and compares against wall-clock time,
/// so it survives sleep, and holds reminders back while nobody is at the keyboard.
@MainActor
final class Scheduler: ObservableObject {
    static let shared = Scheduler()

    @Published private(set) var pausedUntil: Date?
    @Published private(set) var lastFired: [ReminderKind: Date] = [:]

    private let settings = AppSettings.shared
    private var loop: Task<Void, Never>?
    private var lastTick = Date()
    private var awayPeak: TimeInterval = 0

    private static let pauseKey = "pausedUntil"

    private init() {
        let stored = UserDefaults.standard.double(forKey: Self.pauseKey)
        if stored > Date().timeIntervalSince1970 {
            pausedUntil = Date(timeIntervalSince1970: stored)
        }
        resetAll()
        settings.onScheduleChange = { [weak self] kind in
            self?.reset(kind)
        }
    }

    var isPaused: Bool {
        guard let until = pausedUntil else { return false }
        return until > Date()
    }

    func start() {
        guard loop == nil else { return }
        lastTick = Date()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.tick()
            }
        }
    }

    /// When the reminder is next due, or nil if it is off or everything is paused.
    func nextFire(_ kind: ReminderKind) -> Date? {
        guard settings.isEnabled(kind), !isPaused else { return nil }
        let base = lastFired[kind] ?? Date()
        return base.addingTimeInterval(settings.interval(kind))
    }

    func pauseForToday() {
        let until = Day.end(containing: Date())
        pausedUntil = until
        UserDefaults.standard.set(until.timeIntervalSince1970, forKey: Self.pauseKey)
        OverlayController.shared.dismiss(animated: true)
    }

    func resume() {
        pausedUntil = nil
        UserDefaults.standard.removeObject(forKey: Self.pauseKey)
        resetAll()
    }

    private func reset(_ kind: ReminderKind) {
        lastFired[kind] = Date()
    }

    private func resetAll() {
        let now = Date()
        var fresh: [ReminderKind: Date] = [:]
        for kind in ReminderKind.allCases {
            fresh[kind] = now
        }
        lastFired = fresh
    }

    private func tick() {
        let now = Date()
        let gap = now.timeIntervalSince(lastTick)
        lastTick = now

        if let until = pausedUntil {
            if until > now { return }
            resume()
            return
        }

        // The Mac was asleep: start the intervals afresh.
        if gap > 90 {
            resetAll()
            return
        }

        let focusing = FocusSession.shared.isActive
        if focusing {
            // In a focus session the user is working, whether or not they touch the keyboard.
            awayPeak = 0
        } else {
            // Nobody is at the keyboard: hold everything. A long absence counts as a break.
            let idle = idleSeconds(at: now)
            if idle > 120 {
                awayPeak = max(awayPeak, idle)
                return
            }
            if awayPeak > 0 {
                let wasLongBreak = awayPeak >= 300
                awayPeak = 0
                if wasLongBreak {
                    resetAll()
                    return
                }
            }
        }

        if OverlayController.shared.isShowing { return }

        var due: [ReminderKind: Date] = [:]
        for kind in ReminderKind.allCases {
            due[kind] = nextFire(kind)
        }
        if let kind = Self.pick(due: due, now: now, focusing: focusing) {
            fire(kind, at: now)
        }
    }

    /// Which reminder to fire now, if any: the rest break first, then posture, then blink.
    /// A focus session holds the rest break back. Its due time does not move, so a break that
    /// came due meanwhile shows as soon as the session ends, and one that did not still shows
    /// in its own time.
    nonisolated static func pick(due: [ReminderKind: Date], now: Date, focusing: Bool) -> ReminderKind? {
        let order: [ReminderKind] = [.rest, .posture, .blink]
        return order.first { kind in
            if kind == .rest && focusing { return false }
            guard let at = due[kind] else { return false }
            return at <= now
        }
    }

    private func fire(_ kind: ReminderKind, at now: Date) {
        var updated = lastFired
        updated[kind] = now
        lastFired = updated
        // A rest break stays up until it is dismissed, and nothing else fires while it is.
        if let toast = kind.toast {
            holdOff(ReminderKind.allCases.filter { $0 != kind }, until: now.addingTimeInterval(toast.duration + 45))
        }
        OverlayController.shared.show(kind)
    }

    // MARK: - Focus sessions

    /// A rest break was taken off the screen unanswered: it is due again straight away.
    func restStillDue() {
        var updated = lastFired
        updated[.rest] = Date().addingTimeInterval(-settings.interval(.rest))
        lastFired = updated
    }

    /// Keeps blink and posture clear of a toast that is not one of theirs.
    func holdQuickReminders(until clearAt: Date) {
        holdOff([.blink, .posture], until: clearAt)
    }

    /// Keeps reminders from piling up back to back: none of `kinds` fires before `clearAt`.
    private func holdOff(_ kinds: [ReminderKind], until clearAt: Date) {
        var updated = lastFired
        for kind in kinds {
            if let due = nextFire(kind), due < clearAt {
                updated[kind] = clearAt.addingTimeInterval(-settings.interval(kind))
            }
        }
        lastFired = updated
    }

    // MARK: - Rest break buttons

    private static let snooze: TimeInterval = 5 * 60

    /// "done": the break is over, and every interval starts afresh.
    func finishRest() {
        OverlayController.shared.dismiss(animated: true)
        resetAll()
    }

    /// "snooze": the break goes away and comes back in five minutes.
    func snoozeRest() {
        OverlayController.shared.dismiss(animated: true)
        let now = Date()
        var updated = lastFired
        updated[.rest] = now.addingTimeInterval(Self.snooze - settings.interval(.rest))
        lastFired = updated
        holdOff([.blink, .posture], until: now.addingTimeInterval(45))
    }

    /// Seconds since the user was last known to be at the computer: the last keyboard or mouse
    /// input (needs no permissions), or the end of a focus session if that was later.
    private func idleSeconds(at now: Date) -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: UInt32.max) else { return 0 }
        let sinceInput = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        guard let focusEnded = FocusSession.shared.endedAt else { return sinceInput }
        return min(sinceInput, now.timeIntervalSince(focusEnded))
    }
}
