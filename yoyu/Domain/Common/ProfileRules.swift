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

    /// 业务日期计算采用的日历与时区。
    nonisolated static var calendar: Calendar {
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
    static func retirementDate(year: Int?, month: Int?, gender: String, femaleAge: Int?) -> Date? {
        guard let year, let month, (1900...9999).contains(year), (1...12).contains(month) else { return nil }
        let age: Int
        if gender == "男" { age = 60 }
        else if gender == "女", let femaleAge, [50, 55].contains(femaleAge) { age = femaleAge }
        else { return nil }
        let original = (year + age) * 12 + month - 1
        let elapsed = original - 2025 * 12
        let delay = elapsed < 0 ? 0 : min(age == 50 ? 60 : 36, elapsed / (age == 50 ? 2 : 4) + 1)
        let total = original + delay
        return calendar.date(from: DateComponents(year: total / 12, month: total % 12 + 1, day: 1))
    }

    static func statutoryRetirement(year: Int?, month: Int?, gender: String, femaleAge: Int?) -> String {
        guard let retirement = retirementDate(year: year, month: month, gender: gender, femaleAge: femaleAge) else {
            return gender == "女" && year != nil && month != nil ? "请选择退休类别" : "待完善"
        }
        let parts = calendar.dateComponents([.year, .month], from: retirement)
        return "\(parts.year!) 年 \(parts.month!) 月"
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
    nonisolated static let maximumMoneyCents: Int64 = 100_000_000_000_00
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
