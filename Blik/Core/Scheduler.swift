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

        // Nobody is at the keyboard: hold everything. A long absence counts as a break.
        let idle = idleSeconds()
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

        if OverlayController.shared.isShowing { return }

        let order: [ReminderKind] = [.rest, .posture, .blink]
        for kind in order {
            if let due = nextFire(kind), due <= now {
                fire(kind, at: now)
                break
            }
        }
    }

    private func fire(_ kind: ReminderKind, at now: Date) {
        var updated = lastFired
        updated[kind] = now
        lastFired = updated
        // A rest break stays up until it is dismissed, and nothing else fires while it is.
        if kind != .rest {
            holdOff(ReminderKind.allCases.filter { $0 != kind }, until: now.addingTimeInterval(kind.duration + 45))
        }
        OverlayController.shared.show(kind)
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

    /// Seconds since the last keyboard or mouse input. Needs no permissions.
    private func idleSeconds() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: UInt32.max) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}
