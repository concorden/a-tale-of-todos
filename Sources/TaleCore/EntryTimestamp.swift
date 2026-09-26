import Foundation

public enum EntryTimestamp {
    public static func label(for date: Date, relativeTo now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        if days == 0 {
            let seconds = max(0, now.timeIntervalSince(date))
            if seconds < 60 { return "just now" }
            if seconds < 3_600 { return "\(Int(seconds / 60)) min ago" }
            return "\(Int(seconds / 3_600)) hr ago"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        if days == 1 {
            formatter.dateFormat = "HH:mm"
            return "yesterday \(formatter.string(from: date))"
        }
        if (2...6).contains(days) {
            formatter.dateFormat = "EEEE HH:mm"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            formatter.dateFormat = "d MMM HH:mm"
        } else {
            formatter.dateFormat = "d MMM yyyy HH:mm"
        }
        return formatter.string(from: date)
    }
}
