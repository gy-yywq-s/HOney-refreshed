// Date/time rendering with the same output the Web produces (lib/format.ts,
// en-GB): "Wednesday, 2 September", "Wed 2 Sept", "13:30", "3 h 12 min".
// Names are spelled out here rather than taken from ICU so Linux CI, the
// simulator and the device all print exactly what the Web prints ("Sept",
// "June", "July" — the en-GB forms JavaScript uses). "iso date" means a
// local-zone YYYY-MM-DD. Everything goes through Calendar.schoolLocal so
// tests can pin the zone.

import Foundation

public enum Formatters {
    static let monthsLong = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    static let monthsShort = ["Jan", "Feb", "Mar", "Apr", "May", "June", "July", "Aug", "Sept", "Oct", "Nov", "Dec"]
    static let weekdaysLong = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static let weekdaysShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private static func parts(_ date: Date) -> DateComponents {
        Calendar.schoolLocal.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: date)
    }

    private static func pad2(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

    // MARK: ISO dates

    public static func toIsoDate(_ date: Date) -> String {
        let p = parts(date)
        return "\(p.year!)-\(pad2(p.month!))-\(pad2(p.day!))"
    }

    public static func todayIsoDate(now: Date = HOneyClock.now()) -> String {
        toIsoDate(now)
    }

    /// Parses YYYY-MM-DD as a local date (midnight in the school zone).
    public static func parseIsoDate(_ iso: String) -> Date {
        let numbers = iso.split(separator: "-").compactMap { Int($0) }
        var comps = DateComponents()
        comps.year = numbers.count > 0 ? numbers[0] : 1970
        comps.month = numbers.count > 1 ? numbers[1] : 1
        comps.day = numbers.count > 2 ? numbers[2] : 1
        return Calendar.schoolLocal.date(from: comps) ?? Date(timeIntervalSince1970: 0)
    }

    /// True only for a real calendar date ("2026-13-45" is not a day).
    public static func isValidIsoDate(_ iso: String) -> Bool {
        guard iso.wholeMatch(of: #/\d{4}-\d{2}-\d{2}/#) != nil else { return false }
        return toIsoDate(parseIsoDate(iso)) == iso
    }

    public static func shiftIsoDate(_ iso: String, days: Int) -> String {
        let d = Calendar.schoolLocal.date(byAdding: .day, value: days, to: parseIsoDate(iso)) ?? parseIsoDate(iso)
        return toIsoDate(d)
    }

    /// The Monday of the school week containing this day.
    public static func mondayOf(_ iso: String) -> String {
        let weekday = Calendar.schoolLocal.component(.weekday, from: parseIsoDate(iso)) // Sun = 1
        let offset = (weekday + 5) % 7 // Mon = 0
        return shiftIsoDate(iso, days: -offset)
    }

    // MARK: Clock and calendar text

    /// "13:30"
    public static func time(_ epochMillis: Int64) -> String {
        let p = parts(Date(epochMillis: epochMillis))
        return "\(pad2(p.hour!)):\(pad2(p.minute!))"
    }

    public static func timeRange(_ start: Int64, _ end: Int64) -> String {
        "\(time(start))–\(time(end))"
    }

    /// "Wednesday, 2 September" — the timetable bar's heading.
    public static func dayTitle(_ iso: String) -> String {
        let p = parts(parseIsoDate(iso))
        return "\(weekdaysLong[p.weekday! - 1]), \(p.day!) \(monthsLong[p.month! - 1])"
    }

    /// "Wednesday 2 September 2026"
    public static func dayHeading(_ iso: String) -> String {
        let p = parts(parseIsoDate(iso))
        return "\(weekdaysLong[p.weekday! - 1]) \(p.day!) \(monthsLong[p.month! - 1]) \(p.year!)"
    }

    /// "Wed 2 Sept" — en-GB abbreviated month.
    public static func shortDate(_ epochMillis: Int64) -> String {
        shortDate(Date(epochMillis: epochMillis))
    }

    public static func shortDate(_ date: Date) -> String {
        let p = parts(date)
        return "\(weekdaysShort[p.weekday! - 1]) \(p.day!) \(monthsShort[p.month! - 1])"
    }

    /// "Wed 2 Sept" for the Day stepper's compact form.
    public static func stepperDate(_ iso: String) -> String {
        shortDate(parseIsoDate(iso))
    }

    /// "September 2026"
    public static func monthLabel(_ date: Date) -> String {
        let p = parts(date)
        return "\(monthsLong[p.month! - 1]) \(p.year!)"
    }

    /// "2 Sept"
    static func dayMonth(_ date: Date) -> String {
        let p = parts(date)
        return "\(p.day!) \(monthsShort[p.month! - 1])"
    }

    /// "just now" / "5 min ago" / "3 h ago" / "2 Sept"
    public static func timeAgo(_ iso: String, now: Date = HOneyClock.now()) -> String {
        guard let date = ISODate.parse(iso) else { return "" }
        let min = Int((now.timeIntervalSince(date) / 60).rounded())
        if min < 1 { return "just now" }
        if min < 60 { return "\(min) min ago" }
        let h = Int((Double(min) / 60).rounded())
        if h < 24 { return "\(h) h ago" }
        return dayMonth(date)
    }

    public static func isStale(_ iso: String?, maxMinutes: Int = 60, now: Date = HOneyClock.now()) -> Bool {
        guard let iso, let date = ISODate.parse(iso) else { return true }
        return now.timeIntervalSince(date) > Double(maxMinutes) * 60
    }

    /// A coarse day bucket (days since epoch — the only public time
    /// granularity Experiences has): "2 Sept 2026".
    public static func dayBucket(_ day: Int) -> String {
        coarse(Date(timeIntervalSince1970: TimeInterval(day) * 86_400))
    }

    /// Coarse (date-only) rendering of an epoch-ms timestamp.
    public static func coarseDate(_ epochMillis: Int64) -> String {
        coarse(Date(epochMillis: epochMillis))
    }

    private static func coarse(_ date: Date) -> String {
        let p = parts(date)
        return "\(p.day!) \(monthsShort[p.month! - 1]) \(p.year!)"
    }

    /// "3 h 12 min" style remaining-time label (cooldowns, Now/Next).
    public static func remaining(_ ms: Int64) -> String {
        let totalMin = max(1, Int((Double(ms) / 60_000).rounded(.up)))
        let h = totalMin / 60
        let min = totalMin % 60
        if h == 0 { return "\(min) min" }
        return min == 0 ? "\(h) h" : "\(h) h \(min) min"
    }

    /// "Today" / "Yesterday" / "Tue 1 Sept" — for rows of the student's own lessons.
    public static func relativeDay(_ epochMillis: Int64, now: Date = HOneyClock.now()) -> String {
        let date = Date(epochMillis: epochMillis)
        let cal = Calendar.schoolLocal
        if cal.isDate(date, inSameDayAs: now) { return L10n.t("Today") }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(date, inSameDayAs: yesterday) {
            return L10n.t("Yesterday")
        }
        return shortDate(date)
    }

    /// "31 Aug – 4 Sept" for the week starting at `monday` (through `endOffset` days).
    public static func weekRange(monday: String, endOffset: Int = 4) -> String {
        let a = parseIsoDate(monday)
        let b = parseIsoDate(shiftIsoDate(monday, days: endOffset))
        let pa = parts(a)
        let pb = parts(b)
        return pa.month == pb.month
            ? "\(pa.day!) – \(dayMonth(b))"
            : "\(dayMonth(a)) – \(dayMonth(b))"
    }

    /// "Thursday" — the weekday name for the Home card's beyond-today form.
    public static func weekdayName(_ epochMillis: Int64) -> String {
        weekdaysLong[parts(Date(epochMillis: epochMillis)).weekday! - 1]
    }

    /// The short weekday for the Week matrix column header ("Mon").
    public static func weekdayShort(_ iso: String) -> String {
        weekdaysShort[parts(parseIsoDate(iso)).weekday! - 1]
    }

    /// The day of month for the Week header ("2").
    public static func dayNumber(_ iso: String) -> Int {
        parts(parseIsoDate(iso)).day!
    }
}
