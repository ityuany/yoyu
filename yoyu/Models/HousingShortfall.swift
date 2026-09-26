import Foundation

struct HousingShortfallMonth: Identifiable {
    enum Missing: String {
        case salary = "缺少工资资料"
        case limit = "缺少基数范围"
        case base = "缺少已录缴存基数"
        case rate = "缺少个人缴存比例"
    }

    let employmentID: String
    let month: Date
    let wageCents: Int64?
    let expectedBaseCents: Int64?
    let recordedBaseCents: Int64?
    let rateBasisPoints: Int64?
    let limitEvidence: LimitEvidence?
    let personalShortfallCents: Int64?
    let missing: Missing?

    var id: String { "\(employmentID)-\(ProfileRules.dateKey(month))" }
}

struct HousingShortfallCompany: Identifiable {
    let job: Employment
    let months: [HousingShortfallMonth]
    var id: String { job.id }
    var comparableCount: Int { months.filter { $0.personalShortfallCents != nil }.count }
    var missingCount: Int { months.count - comparableCount }
    var positiveCount: Int { months.filter { ($0.personalShortfallCents ?? 0) > 0 }.count }
    var personalShortfallCents: Int64 { months.compactMap(\.personalShortfallCents).reduce(0, +) }
}

enum HousingShortfallRules {
    static func calculate(
        jobs: [Employment], salaries: [SalaryStage], contributions: [ContributionStage],
        limits: [HousingFundLimit], through date: Date
    ) -> [HousingShortfallCompany] {
        let calendar = ProfileRules.calendar
        guard let thisMonth = calendar.dateInterval(of: .month, for: date)?.start,
              let previousMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth) else { return [] }
        let orderedLimits = Dictionary(grouping: limits, by: \.id).values
            .compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted { $0.effectiveMonth > $1.effectiveMonth }
        return CareerRules.employments(jobs).compactMap { job in
            guard let start = job.start,
                  let first = calendar.dateInterval(of: .month, for: start)?.start,
                  let last = calendar.dateInterval(of: .month, for: min(job.end ?? date, previousMonth))?.start,
                  first <= last else { return nil }
            var month = first.addingTimeInterval(12 * 60 * 60)
            let lastMonth = last.addingTimeInterval(12 * 60 * 60)
            var results: [HousingShortfallMonth] = []
            while month <= lastMonth {
                let monthEnd = calendar.dateInterval(of: .month, for: month)!.end.addingTimeInterval(-1)
                let wage = CareerRules.salary(salaries, for: job, on: monthEnd)?.salaryCents
                let limit = orderedLimits.first { $0.effectiveMonth <= month }
                let stage = CareerRules.contribution(contributions, for: job, kind: .housing, on: month)
                let base = stage?.housingBaseCents
                let rate = stage?.housingBasisPoints
                let expected = wage.flatMap { wage in limit.map { min(max(wage, $0.lowerCents), $0.upperCents) } }
                let missing: HousingShortfallMonth.Missing? = wage == nil ? .salary
                    : limit == nil ? .limit : base == nil ? .base
                    : rate == nil || rate == 0 ? .rate : nil
                let gap = expected.flatMap { expected in base.map { max(expected - $0, 0) } }
                let amount = missing == nil ? ProfileRules.monthlyContribution(salaryCents: gap, rateBasisPoints: rate) : nil
                results.append(HousingShortfallMonth(
                    employmentID: job.id, month: month, wageCents: wage,
                    expectedBaseCents: expected, recordedBaseCents: base,
                    rateBasisPoints: rate, limitEvidence: limit?.evidence,
                    personalShortfallCents: amount, missing: missing
                ))
                guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
                month = next
            }
            return HousingShortfallCompany(job: job, months: results.reversed())
        }
    }
}
