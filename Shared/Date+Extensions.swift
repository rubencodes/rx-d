import Foundation

// DateFormatter is thread-safe for formatting (immutable use), so these cached
// instances are safe to share across actors. Marked nonisolated(unsafe) because the
// project defaults to MainActor isolation but these helpers are used from the widget
// and AppIntent (nonisolated) contexts too.
private let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone.current
    return f
}()

private let isoTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone.current
    return f
}()

private let hhmmFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone.current
    return f
}()

private nonisolated(unsafe) let iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

extension Date {
    nonisolated var isoDateString: String { isoDateFormatter.string(from: self) }
    nonisolated var isoTimeString: String { isoTimeFormatter.string(from: self) }
    nonisolated var hhmmString: String { hhmmFormatter.string(from: self) }
    nonisolated var iso8601String: String { iso8601Formatter.string(from: self) }

    // Returns a Date representing this date at the time-of-day encoded in `time`
    nonisolated func settingTime(from time: Date) -> Date {
        let cal = Calendar.current
        let timeComponents = cal.dateComponents([.hour, .minute, .second], from: time)
        return cal.date(bySettingHour: timeComponents.hour ?? 0,
                        minute: timeComponents.minute ?? 0,
                        second: 0,
                        of: self) ?? self
    }

    // Minutes since midnight for quiet-hours comparisons
    nonisolated var minutesSinceMidnight: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
