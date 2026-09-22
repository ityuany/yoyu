import Foundation

enum SeverancePlan: String, Codable, CaseIterable, Identifiable {
    case n, nPlusOne, twoN, customAmount

    // 旧自定义金额仅保留读取兼容，不再提供新建入口。
    static let selectable: [Self] = [.n, .nPlusOne, .twoN]

    var id: String { rawValue }
    var title: String {
        switch self {
        case .n: "N"
        case .nPlusOne: "N+1"
        case .twoN: "2N"
        case .customAmount: "自定义金额"
        }
    }
}

struct SeveranceSettings: Codable, Equatable {
    var plan: SeverancePlan = .nPlusOne
    var baseSalaryCents: Int64?
    var noticeSalaryCents: Int64?
    var tenureHundredths: Int64?
    var customAmountCents: Int64?
    var tripleAverageSalaryCents: Int64?

    // 保留所选预测方案；旧手动基数与年限仍统一从职业履历推算。
    var automatic: Self {
        var result = Self(plan: SeverancePlan.selectable.contains(plan) ? plan : .nPlusOne)
        result.tripleAverageSalaryCents = tripleAverageSalaryCents
        return result
    }
}

/// 可调整的税前情景估算；地区三倍社平标准由用户提供。
enum SeveranceRules {
    struct Estimate {
        let amountCents: Int64
        let tenureHundredths: Int64?
        let baseSalaryCents: Int64?
        let noticeSalaryCents: Int64?
        var isDoubleCapped: Bool = false
    }

    /// 最近 12 个完整自然月；不足 12 个月按本企业实际任职月数（零月按日折算）。
    /// 薪资阶段中的年终奖按 12 个月分摊，不读取股票、理财等资产。
    static func averageSalary(stages: [SalaryStage], job: Employment, on date: Date) -> Int64? {
        let calendar = ProfileRules.calendar
        guard let end = calendar.dateInterval(of: .month, for: date)?.start,
              let start = calendar.date(byAdding: .month, value: -12, to: end),
              let hire = job.start else { return nil }
        return monthlyIncome(stages: stages, job: job, start: max(start, calendar.startOfDay(for: hire)), end: end, includeBonus: true)
    }

    static func previousMonthSalary(stages: [SalaryStage], job: Employment, on date: Date) -> Int64? {
        let calendar = ProfileRules.calendar
        guard let end = calendar.dateInterval(of: .month, for: date)?.start,
              let start = calendar.date(byAdding: .month, value: -1, to: end),
              let hire = job.start else { return nil }
        return monthlyIncome(stages: stages, job: job, start: max(start, calendar.startOfDay(for: hire)), end: end, includeBonus: false)
    }

    private static func monthlyIncome(stages: [SalaryStage], job: Employment, start: Date, end: Date, includeBonus: Bool) -> Int64? {
        guard start < end else { return nil }
        let calendar = ProfileRules.calendar
        let stages = CareerRules.stages(stages, for: job)
        guard !stages.contains(where: { $0.effectiveDate == nil }) else { return nil }
        let dated = stages.map { (date: calendar.startOfDay(for: $0.effectiveDate!), stage: $0) }
            .filter { $0.date < end }.sorted { $0.date < $1.date }
        guard Set(dated.map(\.date)).count == dated.count else { return nil }
        var cursor = start
        var total = Decimal.zero
        var months = Decimal.zero
        while cursor < end {
            guard let stage = dated.last(where: { $0.date <= cursor })?.stage,
                  let salary = validMoney(stage.salaryCents),
                  let bonus = validMoney(includeBonus ? (stage.bonusCents ?? 0) : 0),
                  let month = calendar.dateInterval(of: .month, for: cursor),
                  let days = calendar.range(of: .day, in: .month, for: cursor)?.count else { return nil }
            let next = min(end, month.end, dated.first(where: { $0.date > cursor })?.date ?? end)
            let fraction = Decimal(calendar.dateComponents([.day], from: cursor, to: next).day!) / Decimal(days)
            total += (Decimal(salary) + Decimal(bonus) / 12) * fraction
            months += fraction
            cursor = next
        }
        guard months > 0 else { return nil }
        var average = total / months
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &average, 0, .plain)
        guard rounded >= 0, rounded <= Decimal(ProfileRules.maximumMoneyCents) else { return nil }
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    static func settings(for job: Employment) -> SeveranceSettings? {
        guard let data = job.severanceData else { return SeveranceSettings() }
        return try? JSONDecoder().decode(SeveranceSettings.self, from: data)
    }

    static func tenureHundredths(start: Date?, on date: Date) -> Int64? {
        guard let start else { return nil }
        let calendar = ProfileRules.calendar
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: date)
        guard first <= last,
              let years = calendar.dateComponents([.year], from: first, to: last).year,
              (0...100).contains(years),
              let anniversary = calendar.date(byAdding: .year, value: years, to: first),
              let halfYear = calendar.date(byAdding: .month, value: 6, to: anniversary) else { return nil }
        let remainder: Int64
        if years > 0 && last == anniversary { remainder = 0 }
        else { remainder = last < halfYear ? 50 : 100 }
        let value = Int64(years) * 100 + remainder
        return value <= 10_000 ? value : nil
    }

    static func estimate(settings: SeveranceSettings, job: Employment, salaryCents: Int64?, noticeSalaryCents: Int64? = nil, on date: Date) -> Estimate? {
        guard job.isCurrent(on: date) else { return nil }
        if settings.plan == .customAmount {
            guard let amount = validMoney(settings.customAmountCents) else { return nil }
            return Estimate(amountCents: amount, tenureHundredths: nil, baseSalaryCents: nil, noticeSalaryCents: nil)
        }
        guard var tenure = settings.tenureHundredths ?? tenureHundredths(start: job.start, on: date),
              (0...10_000).contains(tenure),
              var base = validMoney(settings.baseSalaryCents ?? salaryCents) else { return nil }
        var capped = false
        if let cap = settings.tripleAverageSalaryCents {
            guard validMoney(cap) != nil, cap > 0 else { return nil }
            if base > cap {
                base = cap
                tenure = min(tenure, 1_200)
                capped = true
            }
        }
        let notice: Int64?
        if settings.plan == .nPlusOne {
            guard let value = validMoney(settings.noticeSalaryCents ?? noticeSalaryCents) else { return nil }
            notice = value
        } else { notice = nil }
        let multiplier: Decimal = settings.plan == .twoN ? 2 : 1
        var amount = Decimal(base) * Decimal(tenure) / 100 * multiplier + Decimal(notice ?? 0)
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &amount, 0, .plain)
        guard rounded >= 0, rounded <= Decimal(ProfileRules.maximumMoneyCents) else { return nil }
        return Estimate(amountCents: NSDecimalNumber(decimal: rounded).int64Value,
                        tenureHundredths: tenure, baseSalaryCents: base, noticeSalaryCents: notice, isDoubleCapped: capped)
    }

    static func wealth(currentCents: Int64?, compensationCents: Int64?) -> Int64? {
        guard let current = validMoney(currentCents), let compensation = validMoney(compensationCents),
              current <= ProfileRules.maximumMoneyCents - compensation else { return nil }
        return current + compensation
    }

    private static func validMoney(_ value: Int64?) -> Int64? {
        guard let value, (0...ProfileRules.maximumMoneyCents).contains(value) else { return nil }
        return value
    }
}
