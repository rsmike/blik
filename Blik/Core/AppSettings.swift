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

    @Published var theme: Theme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }

    @Published var dimScreen: Bool {
        didSet { UserDefaults.standard.set(dimScreen, forKey: "dimScreen") }
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
        theme = Theme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .keyboard
        dimScreen = defaults.object(forKey: "dimScreen") as? Bool ?? true
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
