import Foundation
import Testing
@testable import TaleCore

struct EntryTimestampTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        return calendar
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)!
    }

    private func label(_ value: String, now: String = "2026-09-25 16:00:00") -> String {
        EntryTimestamp.label(for: date(value), relativeTo: date(now), calendar: calendar)
    }

    @Test func relativeTimeThresholds() {
        #expect(label("2026-09-25 15:59:01") == "just now")
        #expect(label("2026-09-25 15:59:00") == "1 min ago")
        #expect(label("2026-09-25 15:00:01") == "59 min ago")
        #expect(label("2026-09-25 15:00:00") == "1 hr ago")
        #expect(label("2026-09-25 13:00:00") == "3 hr ago")
    }

    @Test func calendarDaysTakePriorityOverElapsedTime() {
        #expect(label("2026-09-24 23:55:00", now: "2026-09-25 00:05:00") == "yesterday 23:55")
        #expect(label("2026-09-24 23:59:50", now: "2026-09-25 00:00:10") == "yesterday 23:59")
        #expect(label("2025-12-31 14:56:00", now: "2026-01-01 16:00:00") == "yesterday 14:56")
    }

    @Test func weekdayAndAbsoluteDateThresholds() {
        #expect(label("2026-09-23 14:56:00") == "Wednesday 14:56")
        #expect(label("2026-09-19 14:56:00") == "Saturday 14:56")
        #expect(label("2026-09-18 14:56:00") == "18 Sep 14:56")
        #expect(label("2025-09-18 14:56:00") == "18 Sep 2025 14:56")
    }

    @Test func daylightSavingUsesCalendarDays() {
        #expect(label("2026-03-28 14:56:00", now: "2026-03-29 16:00:00") == "yesterday 14:56")
        #expect(label("2026-10-24 14:56:00", now: "2026-10-25 16:00:00") == "yesterday 14:56")
    }

    @Test func clockCorrectionsDoNotProduceNegativeAges() {
        #expect(label("2026-09-25 16:00:30") == "just now")
        #expect(label("2026-09-26 14:56:00") == "26 Sep 14:56")
    }
}
