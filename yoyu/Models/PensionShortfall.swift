import Foundation

struct PensionShortfallMonth: Identifiable {
    enum Missing: String {
        case salary = "缺少工资资料"
        case base = "缺少缴纳基数配置"
        case rate = "缺少个人缴纳比例"
        case limit = "缺少基数范围"
    }

    let employmentID: String
    let month: Date
    let wageCents: Int64?
    let expectedBaseCents: Int64?
    let configuredBaseCents: Int64?
    let configuredRateBasisPoints: Int64?
    let configuredPaymentCents: Int64?
    let limitEvidence: LimitEvidence?
    let shortfallBaseCents: Int64?
    let personalShortfallCents: Int64?
    let missing: Missing?

    var id: String { "\(employmentID)-\(ProfileRules.dateKey(month))" }
    var expectedPaymentCents: Int64? {
        ProfileRules.monthlyContribution(salaryCents: expectedBaseCents, rateBasisPoints: configuredRateBasisPoints)
    }
    var comparison: Comparison? {
        guard let expectedBaseCents, let configuredBaseCents else { return nil }
        if configuredBaseCents < expectedBaseCents { return .below }
        if configuredBaseCents > expectedBaseCents { return .above }
        return .matches
    }

    enum Comparison {
        case matches, above, below
        var title: String {
            switch self {
            case .matches: "符合预期"
            case .above: "高于预期"
            case .below: "低于预期"
            }
        }
    }
}

struct PensionShortfallCompany: Identifiable {
    let job: Employment
    let months: [PensionShortfallMonth]

    var id: String { job.id }
    var shortfallMonths: [PensionShortfallMonth] { months.filter { ($0.personalShortfallCents ?? 0) > 0 } }
    var comparableCount: Int { months.filter { $0.personalShortfallCents != nil }.count }
    var missingCount: Int { months.count - comparableCount }
    var positiveCount: Int { shortfallMonths.count }
    var personalShortfallCents: Int64 { months.compactMap(\.personalShortfallCents).reduce(0, +) }
    var averageMonthlyShortfallCents: Int64? {
        guard comparableCount > 0 else { return nil }
        return (personalShortfallCents + Int64(comparableCount / 2)) / Int64(comparableCount)
    }
    var shortfallRate: Double? {
        let compared = months.filter { $0.personalShortfallCents != nil }
        let expected = compared.compactMap(\.expectedBaseCents).reduce(Int64.zero, +)
        guard expected > 0 else { return nil }
        let gap = compared.compactMap(\.shortfallBaseCents).reduce(Int64.zero, +)
        return Double(gap) / Double(expected)
    }
}

enum PensionShortfallRules {
    static func calculate(
        jobs: [Employment], salaries: [SalaryStage], bonuses: [BonusPayment] = [], contributions: [ContributionStage],
        limits: [SocialInsuranceLimit], through date: Date
    ) -> [PensionShortfallCompany] {
        let calendar = ProfileRules.calendar
        guard let thisMonthStart = calendar.dateInterval(of: .month, for: date)?.start,
              let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) else { return [] }
        let lastCompleteMonth = previousMonthStart.addingTimeInterval(12 * 60 * 60)
        let orderedLimits = Dictionary(grouping: limits, by: \.id).values
            .compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted {
                if $0.effectiveMonth != $1.effectiveMonth { return $0.effectiveMonth > $1.effectiveMonth }
                return $0.modifiedAt > $1.modifiedAt
            }

        return CareerRules.employments(jobs).compactMap { job in
            guard let start = job.start,
                  let firstMonthStart = calendar.dateInterval(of: .month, for: start)?.start,
                  let endMonthStart = calendar.dateInterval(of: .month, for: min(job.end ?? date, lastCompleteMonth))?.start,
                  firstMonthStart <= endMonthStart else { return nil }
            let firstMonth = firstMonthStart.addingTimeInterval(12 * 60 * 60)
            let endMonth = endMonthStart.addingTimeInterval(12 * 60 * 60)
            var month = firstMonth
            var results: [PensionShortfallMonth] = []
            var wageByYear: [Int: Int64?] = [:]
            while month <= endMonth {
                let year = calendar.component(.year, from: month)
                let wage: Int64?
                if let cached = wageByYear[year] { wage = cached }
                else {
                    wage = estimatedWageBase(job: job, salaries: salaries, bonuses: bonuses, year: year)
                    wageByYear[year] = wage
                }
                let limit = orderedLimits.first { $0.effectiveMonth <= month }
                let stage = CareerRules.contribution(contributions, for: job, kind: .pension, on: month)
                let base = stage?.pensionBaseCents
                let rate = stage?.pensionBasisPoints
                let payment = ProfileRules.monthlyContribution(salaryCents: base, rateBasisPoints: rate)
                let missing: PensionShortfallMonth.Missing? = wage == nil ? .salary : limit == nil ? .limit : base == nil ? .base : rate == nil ? .rate : nil
                let expected: Int64? = if let wage, let limit { min(max(wage, limit.lowerCents), limit.upperCents) } else { nil }
                let gap: Int64? = if let expected, let base { max(expected - base, 0) } else { nil }
                let personal = ProfileRules.monthlyContribution(salaryCents: gap, rateBasisPoints: rate)
                results.append(PensionShortfallMonth(
                    employmentID: job.id, month: month, wageCents: wage,
                    expectedBaseCents: expected, configuredBaseCents: base,
                    configuredRateBasisPoints: rate, configuredPaymentCents: payment,
                    limitEvidence: limit?.evidence,
                    shortfallBaseCents: gap, personalShortfallCents: personal, missing: missing
                ))
                guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
                month = next
            }
            return PensionShortfallCompany(job: job, months: results.reversed())
        }
    }

    /// 首年用入职时月薪；此后将上年实际收到的年终奖计入在职月份均值。
    private static func estimatedWageBase(job: Employment, salaries: [SalaryStage], bonuses: [BonusPayment], year: Int) -> Int64? {
        let calendar = ProfileRules.calendar
        guard let start = job.start else { return nil }
        let startYear = calendar.component(.year, from: start)
        if year == startYear {
            let firstMonthEnd = calendar.dateInterval(of: .month, for: start)!.end.addingTimeInterval(-1)
            return CareerRules.salary(salaries, for: job, on: firstMonthEnd)?.salaryCents
        }
        guard year > startYear else { return nil }
        let previousYear = year - 1
        guard let january = calendar.date(from: DateComponents(year: previousYear, month: 1, day: 1)),
              let followingJanuary = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }
        var month = max(calendar.dateInterval(of: .month, for: start)!.start, january)
        var total = Decimal.zero
        var count = 0
        while month < followingJanuary && month <= (job.end ?? .distantFuture) {
            guard let interval = calendar.dateInterval(of: .month, for: month),
                  let stage = CareerRules.salary(salaries, for: job, on: interval.end.addingTimeInterval(-1)),
                  let salary = stage.salaryCents, salary >= 0 else { return nil }
            total += Decimal(salary)
            count += 1
            month = interval.end
        }
        guard count > 0 else { return nil }
        for payment in BonusRules.confirmed(bonuses, for: job) where payment.year == previousYear {
            if let amount = payment.amountCents { total += Decimal(amount) }
        }
        var average = total / Decimal(count)
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &average, 0, .plain)
        guard rounded >= 0, rounded <= Decimal(Int64.max) else { return nil }
        return NSDecimalNumber(decimal: rounded).int64Value
    }
}
