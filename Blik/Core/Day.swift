import Foundation

/// Blik's day runs from 5 AM to 5 AM, so a late night still counts as the same day.
enum Day {
    static let startsAtHour = 5

    private static var boundary: DateComponents {
        DateComponents(hour: startsAtHour, minute: 0, second: 0)
    }

    /// When the day that `date` falls in began.
    static func start(containing date: Date) -> Date {
        Calendar.current.nextDate(after: date, matching: boundary, matchingPolicy: .nextTime, direction: .backward)
            ?? date.addingTimeInterval(-86_400)
    }

    /// When the day that `date` falls in ends.
    static func end(containing date: Date) -> Date {
        Calendar.current.nextDate(after: date, matching: boundary, matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(86_400)
    }
}

/// Remembers which off-screen activities were done today, so a rest break does not offer them again.
enum ActivityLog {
    private static let key = "activitiesDone"

    /// Activity name (lowercased) to the moment it was done, today's entries only.
    private static func today(_ now: Date) -> [String: Double] {
        let stored = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        let since = Day.start(containing: now).timeIntervalSince1970
        return stored.filter { $0.value >= since }
    }

    static func isDoneToday(_ activity: String, now: Date = Date()) -> Bool {
        today(now)[activity.lowercased()] != nil
    }

    static func markDone(_ activity: String, now: Date = Date()) {
        var entries = today(now)
        entries[activity.lowercased()] = now.timeIntervalSince1970
        UserDefaults.standard.set(entries, forKey: key)
    }
}
