import Foundation

struct PensionShortfallMonth: Identifiable {
    enum Missing: String {
        case salary = "缺少工资资料"
        case base = "缺少实际缴费基数"
        case limit = "缺少基数范围"
    }

    let employmentID: String
    let month: Date
    let wageCents: Int64?
    let expectedBaseCents: Int64?
    let actualBaseCents: Int64?
    let baseFromProof: Bool
    let limitEvidence: LimitEvidence?
    let shortfallBaseCents: Int64?
    let personalShortfallCents: Int64?
    let missing: Missing?

    var id: String { "\(employmentID)-\(ProfileRules.dateKey(month))" }
}

struct PensionShortfallCompany: Identifiable {
    let job: Employment
    let months: [PensionShortfallMonth]

    var id: String { job.id }
    var comparableCount: Int { months.filter { $0.personalShortfallCents != nil }.count }
    var missingCount: Int { months.count - comparableCount }
    var positiveCount: Int { months.filter { ($0.personalShortfallCents ?? 0) > 0 }.count }
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
        jobs: [Employment], salaries: [SalaryStage], contributions: [ContributionStage],
        proofMonths: [SocialInsuranceMonth], limits: [SocialInsuranceLimit], through date: Date
    ) -> [PensionShortfallCompany] {
        let calendar = ProfileRules.calendar
        guard let thisMonthStart = calendar.dateInterval(of: .month, for: date)?.start,
              let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) else { return [] }
        let lastCompleteMonth = previousMonthStart.addingTimeInterval(12 * 60 * 60)
        let uniqueProofs = Dictionary(grouping: proofMonths, by: \.id).values
            .compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
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
                    wage = estimatedWageBase(job: job, salaries: salaries, year: year)
                    wageByYear[year] = wage
                }
                let limit = orderedLimits.first { $0.effectiveMonth <= month }
                let proof = uniqueProofs.first {
                    $0.employmentID == job.id && $0.pensionBaseCents != nil
                        && calendar.isDate($0.month, equalTo: month, toGranularity: .month)
                }
                let base = proof?.pensionBaseCents ?? CareerRules.pensionBase(contributions, for: job, on: month)
                let missing: PensionShortfallMonth.Missing? = wage == nil ? .salary : limit == nil ? .limit : base == nil ? .base : nil
                let expected: Int64? = if let wage, let limit { min(max(wage, limit.lowerCents), limit.upperCents) } else { nil }
                let gap: Int64? = if let expected, let base { max(expected - base, 0) } else { nil }
                let personal = ProfileRules.monthlyContribution(salaryCents: gap, rateBasisPoints: 800)
                results.append(PensionShortfallMonth(
                    employmentID: job.id, month: month, wageCents: wage,
                    expectedBaseCents: expected, actualBaseCents: base,
                    baseFromProof: proof != nil, limitEvidence: limit?.evidence,
                    shortfallBaseCents: gap, personalShortfallCents: personal, missing: missing
                ))
                guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
                month = next
            }
            return PensionShortfallCompany(job: job, months: results.reversed())
        }
    }

    /// 同一任职首年用入职时的月薪；后续年度按上年在职月份的已登记月薪与年终奖估算月平均工资。
    private static func estimatedWageBase(job: Employment, salaries: [SalaryStage], year: Int) -> Int64? {
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
            if stage.bonusMonth == calendar.component(.month, from: month), let bonus = stage.bonusCents {
                total += Decimal(bonus)
            }
            count += 1
            month = interval.end
        }
        guard count > 0 else { return nil }
        var average = total / Decimal(count)
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &average, 0, .plain)
        guard rounded >= 0, rounded <= Decimal(Int64.max) else { return nil }
        return NSDecimalNumber(decimal: rounded).int64Value
    }
}
