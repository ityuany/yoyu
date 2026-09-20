import Foundation

/// 个人资料页面使用的纯业务规则。
/// 金额、股票数量和百分比统一用整数保存：金额以“分”为单位，百分比以“万分之一”为单位，避免小数精度误差。
enum ProfileRules {
    /// 以登记日上海时间零点起算，一年按 365 天；复利每满一年复投。
    /// 金额按时间推导，绝不写回本金；负收益最多损失本金。
    static func investmentValue(principal: Int64?, rate: Int64?, registration: Date?, compound: Bool, on date: Date) -> Int64? {
        guard let principal, (0...maximumMoneyCents).contains(principal) else { return nil }
        guard let registration, let rate else { return principal }
        guard (-10_000...10_000).contains(rate),
              registration.timeIntervalSince1970.isFinite, date.timeIntervalSince1970.isFinite else { return nil }
        let elapsed = max(0, date.timeIntervalSince(calendar.startOfDay(for: registration)))
        let years = elapsed / (365 * 24 * 60 * 60)
        guard years <= 1000 else { return nil }
        let r = Decimal(rate) / 10_000
        var total = Decimal(principal)
        if compound {
            for _ in 0..<Int(years) {
                total *= 1 + r
                guard total <= Decimal(maximumMoneyCents) else { return nil }
            }
            total *= 1 + r * Decimal(years - Double(Int(years)))
        } else {
            total *= max(0, 1 + r * Decimal(years))
        }
        guard !total.isNaN, total >= 0, total <= Decimal(maximumMoneyCents) else { return nil }
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &total, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    /// 根据当前应用采用的口径返回退休年龄；未识别的性别不参与推算。
    static func retirementAge(gender: String) -> Int? {
        switch gender {
        case "男": 63
        case "女": 58
        default: nil
        }
    }

    /// 中国大陆普通职工渐进式延迟退休规则（2025 年起）；不计算特殊工种等提前退休情形。
    /// https://www.npc.gov.cn/npc/c2/c30834/202409/t20240914_439634.html
    static func statutoryRetirement(year: Int?, month: Int?, gender: String, femaleAge: Int?) -> String {
        guard let year, let month, (1900...9999).contains(year), (1...12).contains(month) else { return "待完善" }
        let age: Int
        if gender == "男" { age = 60 }
        else if gender == "女", let femaleAge, [50, 55].contains(femaleAge) { age = femaleAge }
        else { return gender == "女" ? "请选择退休类别" : "待完善" }
        let original = (year + age) * 12 + month - 1
        let elapsed = original - 2025 * 12
        let delay = elapsed < 0 ? 0 : min(age == 50 ? 60 : 36, elapsed / (age == 50 ? 2 : 4) + 1)
        let total = original + delay
        return "\(total / 12) 年 \(total % 12 + 1) 月"
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    static func dateKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// 将“从当天 0 点起经过的分钟数”转换为 `HH:mm`，例如 540 分钟显示为 09:00。
    static func timeLabel(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// 可保存金额的上限，单位为分：1000 亿元。
    static let maximumMoneyCents: Int64 = 100_000_000_000_00
    /// 可保存百分比的上限，单位为基点：100%。
    static let maximumPercentBasisPoints: Int64 = 10_000

    /// 将用户输入的元或百分比文本转换为扩大 100 倍的整数；例如 `123.45` 保存为 `12_345`。
    /// 只接受最多两位小数，并在转换前检查上限。
    static func scaledValue(_ text: String, maximum: Int64 = ProfileRules.maximumMoneyCents) -> Int64? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.range(of: #"^[0-9]+(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let decimal = Decimal(string: clean, locale: Locale(identifier: "en_US_POSIX")),
              decimal <= Decimal(maximum) / 100 else { return nil }
        return NSDecimalNumber(decimal: decimal * 100).int64Value
    }

    /// 将以分或基点保存的整数还原为可编辑的十进制文本。
    static func input(_ value: Int64?) -> String {
        guard let value else { return "" }
        return NSDecimalNumber(decimal: Decimal(value) / 100).stringValue
    }

    /// 计算股票市值：`市值（分）= 持股数量（百分之一股）× 单股价格（分）÷ 100`。
    /// 结果按分四舍五入，并拒绝超过可保存金额上限的结果。
    static func stockValue(sharesHundredths: Int64?, priceCents: Int64?) -> Int64? {
        guard let sharesHundredths, let priceCents, sharesHundredths >= 0, priceCents >= 0 else { return nil }
        var amount = Decimal(sharesHundredths) * Decimal(priceCents) / 100
        guard amount <= Decimal(maximumMoneyCents) else { return nil }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &amount, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    /// 计算个人每月养老或公积金缴纳额。
    /// 比例以基点保存，100% 等于 10,000，因此公式为“月薪（分）× 比例（基点）÷ 10,000”，结果按分四舍五入。
    static func monthlyContribution(salaryCents: Int64?, rateBasisPoints: Int64?) -> Int64? {
        guard let salaryCents, let rateBasisPoints,
              (0...maximumMoneyCents).contains(salaryCents),
              (0...maximumPercentBasisPoints).contains(rateBasisPoints) else { return nil }
        var amount = Decimal(salaryCents) * Decimal(rateBasisPoints) / 10_000
        var rounded = Decimal()
        NSDecimalRound(&rounded, &amount, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    /// 解析可为负数的年化收益率；例如 `-2.75` 保存为 `-275` 个基点。
    static func annualReturnRate(_ text: String) -> Int64? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.range(of: #"^-?[0-9]+(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil else { return nil }
        let negative = clean.hasPrefix("-")
        let magnitude = negative ? String(clean.dropFirst()) : clean
        guard let value = scaledValue(magnitude, maximum: maximumPercentBasisPoints) else { return nil }
        return negative ? -value : value
    }

    /// 将以分保存的金额格式化为中文人民币显示文本。
    static func money(_ value: Int64?, compact: Bool = false) -> String {
        guard let value else { return "待填写" }
        let formatted = (Decimal(value) / 100).formatted(
            .currency(code: "CNY").locale(Locale(identifier: "zh_CN"))
                .precision(.fractionLength(compact ? 0...2 : 2...2))
        )
        return formatted.replacingOccurrences(of: #"([¥￥])\s*"#, with: "$1 ", options: .regularExpression)
    }
}

/// 星期枚举与 `Calendar.component(.weekday:)` 保持一致：周日为 1，周六为 7。
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

    /// 按中国大陆时区的公历，取得日期所对应的星期。
    init(_ date: Date) {
        self.init(rawValue: ProfileRules.calendar.component(.weekday, from: date))!
    }

    /// 界面展示顺序从周一开始，而非日历原始的周日开始。
    static let displayOrder: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
}

/// 常规每周工作安排，使用 Int 的二进制位保存七天的工作状态；位为 1 代表上班，0 代表休息。
struct Workweek: Equatable {
    /// 默认周一至周五上班，对应二进制 `0b0111110`，即十进制 62。
    static let `default` = Workweek(mask: 62)

    var mask: Int

    init(mask: Int) {
        self.mask = mask
    }

    /// 判断目标星期对应的二进制位是否为 1。
    func contains(_ weekday: Weekday) -> Bool {
        mask & Self.bit(weekday) != 0
    }

    /// 将指定星期的二进制位设为上班（1）或休息（0）。
    mutating func set(_ weekday: Weekday, isWorkday: Bool) {
        if isWorkday { mask |= Self.bit(weekday) } else { mask &= ~Self.bit(weekday) }
    }

    /// 将星期转换为其对应的二进制位，例如周一是 `1 << 1`。
    private static func bit(_ weekday: Weekday) -> Int { 1 << (weekday.rawValue - 1) }
}

struct Holiday: Identifiable {
    let name: String
    let month: Int
    let firstDay: Int
    let lastDay: Int
    let makeup: [(month: Int, day: Int)]
    var id: String { name }
    /// 节假日包含起止两天，所以天数需要额外加 1。
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

    /// 查询内置官方安排：补班优先返回上班，假期区间返回休息；非收录日期返回 `nil`。
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

    /// 按“个人调整 > 官方调休 > 常规周安排”的优先级计算某一天是否上班。
    static func workday(_ date: Date, workweek: Workweek, followsHolidays: Bool, override: Bool?) -> (isWorkday: Bool, reason: String) {
        if let override { return (override, "个人调整") }
        if followsHolidays, let official = officialDay(date) { return official }
        let isWorkday = workweek.contains(Weekday(date))
        let unknown = followsHolidays && ProfileRules.calendar.component(.year, from: date) != supportedYear
        return (isWorkday, unknown ? "按常规安排估算，未包含该年节假日及调休" : "每周常规安排")
    }
}
