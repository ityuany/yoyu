import Foundation

// Calendar-only values use mainland China's Gregorian calendar, independent of device locale.
enum ProfileRules {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    static func retirementAge(gender: String) -> Int? {
        switch gender {
        case "男": 63
        case "女": 58
        default: nil
        }
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    static func dateKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    static func timeLabel(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// Upper bound for stored money, in cents: 1000 亿元.
    static let maximumMoneyCents: Int64 = 100_000_000_000_00
    /// Upper bound for stored percentages, in basis points: 100%.
    static let maximumPercentBasisPoints: Int64 = 10_000

    // Fixed-point storage avoids binary floating point rounding for money and percentages.
    static func scaledValue(_ text: String, maximum: Int64 = ProfileRules.maximumMoneyCents) -> Int64? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.range(of: #"^[0-9]+(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let decimal = Decimal(string: clean, locale: Locale(identifier: "en_US_POSIX")),
              decimal <= Decimal(maximum) / 100 else { return nil }
        return NSDecimalNumber(decimal: decimal * 100).int64Value
    }

    static func input(_ value: Int64?) -> String {
        guard let value else { return "" }
        return NSDecimalNumber(decimal: Decimal(value) / 100).stringValue
    }

    /// Shares are stored in hundredths; price and resulting market value are in cents.
    static func stockValue(sharesHundredths: Int64?, priceCents: Int64?) -> Int64? {
        guard let sharesHundredths, let priceCents, sharesHundredths >= 0, priceCents >= 0 else { return nil }
        var amount = Decimal(sharesHundredths) * Decimal(priceCents) / 100
        guard amount <= Decimal(maximumMoneyCents) else { return nil }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &amount, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    static func annualReturnRate(_ text: String) -> Int64? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.range(of: #"^-?[0-9]+(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil else { return nil }
        let negative = clean.hasPrefix("-")
        let magnitude = negative ? String(clean.dropFirst()) : clean
        guard let value = scaledValue(magnitude, maximum: maximumPercentBasisPoints) else { return nil }
        return negative ? -value : value
    }

    static func money(_ value: Int64?) -> String {
        guard let value else { return "待填写" }
        return (Decimal(value) / 100).formatted(.currency(code: "CNY").locale(Locale(identifier: "zh_CN")))
    }
}

/// Gregorian weekday numbers, matching `Calendar.component(.weekday:)` where Sunday is 1.
enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .sunday: "周日"
        case .monday: "周一"
        case .tuesday: "周二"
        case .wednesday: "周三"
        case .thursday: "周四"
        case .friday: "周五"
        case .saturday: "周六"
        }
    }

    /// Weekday of `date` in mainland China's calendar.
    init(_ date: Date) {
        self.init(rawValue: ProfileRules.calendar.component(.weekday, from: date))!
    }

    /// Week-listing order used in the UI, starting on Monday.
    static let displayOrder: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
}

/// A regular weekly schedule. Stored as a bit mask indexed by `Weekday.rawValue`.
struct Workweek: Equatable {
    /// Monday through Friday.
    static let `default` = Workweek(mask: 62)

    var mask: Int

    init(mask: Int) {
        self.mask = mask
    }

    func contains(_ weekday: Weekday) -> Bool {
        mask & Self.bit(weekday) != 0
    }

    mutating func set(_ weekday: Weekday, isWorkday: Bool) {
        if isWorkday { mask |= Self.bit(weekday) } else { mask &= ~Self.bit(weekday) }
    }

    private static func bit(_ weekday: Weekday) -> Int { 1 << (weekday.rawValue - 1) }
}

struct Holiday: Identifiable {
    let name: String
    let month: Int
    let firstDay: Int
    let lastDay: Int
    let makeup: [(month: Int, day: Int)]
    var id: String { name }
    var days: Int { lastDay - firstDay + 1 }
    var rangeLabel: String { "\(month) 月 \(firstDay)—\(lastDay) 日" }
}

enum HolidaySchedule {
    static let sourceURL = URL(string: "https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm")!
    static let supportedYear = 2026
    static let holidays: [Holiday] = [
        Holiday(name: "元旦", month: 1, firstDay: 1, lastDay: 3, makeup: [(1, 4)]),
        Holiday(name: "春节", month: 2, firstDay: 15, lastDay: 23, makeup: [(2, 14), (2, 28)]),
        Holiday(name: "清明节", month: 4, firstDay: 4, lastDay: 6, makeup: []),
        Holiday(name: "劳动节", month: 5, firstDay: 1, lastDay: 5, makeup: [(5, 9)]),
        Holiday(name: "端午节", month: 6, firstDay: 19, lastDay: 21, makeup: []),
        Holiday(name: "中秋节", month: 9, firstDay: 25, lastDay: 27, makeup: []),
        Holiday(name: "国庆节", month: 10, firstDay: 1, lastDay: 7, makeup: [(9, 20), (10, 10)])
    ]

    static func officialDay(_ date: Date) -> (isWorkday: Bool, reason: String)? {
        let parts = ProfileRules.calendar.dateComponents([.year, .month, .day], from: date)
        guard parts.year == supportedYear, let month = parts.month, let day = parts.day else { return nil }
        for holiday in holidays {
            if holiday.makeup.contains(where: { $0.month == month && $0.day == day }) {
                return (true, "\(holiday.name)调休补班")
            }
            if month == holiday.month && (holiday.firstDay...holiday.lastDay).contains(day) {
                return (false, "\(holiday.name)放假")
            }
        }
        return nil
    }

    static func workday(_ date: Date, workweek: Workweek, followsHolidays: Bool, override: Bool?) -> (isWorkday: Bool, reason: String) {
        if let override { return (override, "个人调整") }
        if followsHolidays, let official = officialDay(date) { return official }
        let isWorkday = workweek.contains(Weekday(date))
        let unknown = followsHolidays && ProfileRules.calendar.component(.year, from: date) != supportedYear
        return (isWorkday, unknown ? "按常规安排估算，未包含该年节假日及调休" : "每周常规安排")
    }
}
