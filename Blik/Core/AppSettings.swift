import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    /// Called when a reminder is switched on/off or its interval changes.
    var onScheduleChange: ((ReminderKind) -> Void)?

    @Published var enabled: [ReminderKind: Bool] {
        didSet {
            for kind in ReminderKind.allCases where enabled[kind] != oldValue[kind] {
                UserDefaults.standard.set(enabled[kind] ?? true, forKey: Self.enabledKey(kind))
                onScheduleChange?(kind)
            }
        }
    }

    @Published var minutes: [ReminderKind: Int] {
        didSet {
            for kind in ReminderKind.allCases where minutes[kind] != oldValue[kind] {
                UserDefaults.standard.set(minutes[kind] ?? kind.defaultMinutes, forKey: Self.minutesKey(kind))
                onScheduleChange?(kind)
            }
        }
    }

    @Published var dimScreen: Bool {
        didSet { UserDefaults.standard.set(dimScreen, forKey: "dimScreen") }
    }

    /// The off-screen activities a rest break can suggest, as typed: separated by commas or new lines.
    @Published var activitiesText: String {
        didSet { UserDefaults.standard.set(activitiesText, forKey: "activities") }
    }

    static let defaultActivities = "juggle, exercise, meditate, read, play jojo"

    /// Length of a focus session, in minutes.
    @Published var focusMinutes: Int {
        didSet { UserDefaults.standard.set(focusMinutes, forKey: "focusMinutes") }
    }

    static let focusOptions = [10, 15, 20, 25, 30, 45, 50, 60, 90]

    /// The system-wide shortcut that starts and stops a focus session; nil for none.
    @Published var focusHotKey: HotKeyCombo? {
        didSet {
            // An empty entry means "none", as opposed to never having been set.
            UserDefaults.standard.set(focusHotKey?.stored ?? [:], forKey: "focusHotKey")
            HotKey.shared.bind(focusHotKey)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        var storedEnabled: [ReminderKind: Bool] = [:]
        var storedMinutes: [ReminderKind: Int] = [:]
        for kind in ReminderKind.allCases {
            storedEnabled[kind] = defaults.object(forKey: Self.enabledKey(kind)) as? Bool ?? true
            storedMinutes[kind] = defaults.object(forKey: Self.minutesKey(kind)) as? Int ?? kind.defaultMinutes
        }
        enabled = storedEnabled
        minutes = storedMinutes
        dimScreen = defaults.object(forKey: "dimScreen") as? Bool ?? true
        activitiesText = defaults.string(forKey: "activities") ?? Self.defaultActivities
        focusMinutes = defaults.object(forKey: "focusMinutes") as? Int ?? 25
        if let stored = defaults.dictionary(forKey: "focusHotKey") {
            focusHotKey = HotKeyCombo(stored: stored)
        } else {
            focusHotKey = .standard
        }
    }

    /// The activity list, tidied up: trimmed, no blanks, no repeats.
    var activities: [String] {
        var seen = Set<String>()
        return activitiesText
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    /// The activities a rest break may still suggest today.
    func activitiesLeftToday() -> [String] {
        activities.filter { !ActivityLog.isDoneToday($0) }
    }

    func isEnabled(_ kind: ReminderKind) -> Bool {
        enabled[kind] ?? true
    }

    func interval(_ kind: ReminderKind) -> TimeInterval {
        TimeInterval((minutes[kind] ?? kind.defaultMinutes) * 60)
    }

    private static func enabledKey(_ kind: ReminderKind) -> String { "enabled.\(kind.rawValue)" }
    private static func minutesKey(_ kind: ReminderKind) -> String { "minutes.\(kind.rawValue)" }
}
