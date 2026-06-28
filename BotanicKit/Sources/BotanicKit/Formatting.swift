import Foundation

extension TimeInterval {
    /// A compact human duration: "55m", "2h 14m", "2h". Used for live timers and history.
    public var botanicDuration: String {
        let total = Int(self.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
}

extension Int {
    /// Duration from a whole-second count.
    public var botanicDuration: String { TimeInterval(self).botanicDuration }
}

public enum BotanicFormat {
    /// Time-of-day like "9:24 PM".
    public static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale.current
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    /// A relative phrase for a scheduled time, e.g. "in 25m", "in 2h 10m", or "now" when due.
    /// Negative intervals (already past) read as "now".
    public static func relativeToNow(_ target: Date, now: Date = Date()) -> String {
        let delta = target.timeIntervalSince(now)
        if delta <= 30 { return "now" }
        return "in \(delta.botanicDuration)"
    }

    /// Short calendar date like "May 4" or "May 4, 2026" when `includeYear` is set.
    public static func shortDate(_ date: Date, includeYear: Bool = false, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate(includeYear ? "MMMd yyyy" : "MMMd")
        return f.string(from: date)
    }
}
