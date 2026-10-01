import Foundation

struct HousingShortfallMonth: Identifiable {
    enum Missing: String {
        case salary = "缺少工资资料"
        case limit = "缺少基数范围"
        case base = "缺少已录缴存基数"
        case rate = "缺少个人缴存比例"
    }

    /// 所属任职记录的业务标识。
    let employmentID: String
    /// 所属月份。
    let month: Date
    /// 工资金额，单位为分。
    let wageCents: Int64?
    /// 应采用的缴纳基数，单位为分。
    let expectedBaseCents: Int64?
    /// 实际登记的缴纳基数，单位为分。
    let recordedBaseCents: Int64?
    /// 比例，单位为基点。
    let rateBasisPoints: Int64?
    /// 已配置缴纳金额，单位为分。
    let configuredPaymentCents: Int64?
    /// 上下限资料的依据状态。
    let limitEvidence: LimitEvidence?
    /// 个人应补差额，单位为分。
    let personalShortfallCents: Int64?
    /// 缺失信息。
    let missing: Missing?

    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String { "\(employmentID)-\(ProfileRules.dateKey(month))" }
    /// 应缴金额，单位为分。
    var expectedPaymentCents: Int64? {
        ProfileRules.monthlyContribution(salaryCents: expectedBaseCents, rateBasisPoints: rateBasisPoints)
    }
    /// 比较结果。
    var comparison: Comparison? {
        guard missing == nil, let expectedBaseCents, let recordedBaseCents else { return nil }
        if recordedBaseCents < expectedBaseCents { return .below }
        if recordedBaseCents > expectedBaseCents { return .above }
        return .matches
    }

    enum Comparison {
        case matches, above, below
        /// 展示标题。
        var title: String {
            switch self {
            case .matches: "符合预期"
            case .above: "高于预期"
            case .below: "低于预期"
            }
        }
    }
}

struct HousingShortfallCompany: Identifiable {
    /// 本次计算使用的任职记录。
    let job: Employment
    /// 还款期数，单位为月。
    let months: [HousingShortfallMonth]
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String { job.id }
    /// 存在缴纳缺口的月份数量。
    var shortfallMonths: [HousingShortfallMonth] { months.filter { ($0.personalShortfallCents ?? 0) > 0 } }
    /// 可比较记录数量。
    var comparableCount: Int { months.filter { $0.personalShortfallCents != nil }.count }
    /// 缺失记录数量。
    var missingCount: Int { months.count - comparableCount }
    /// 存在正缺口的记录数量。
    var positiveCount: Int { shortfallMonths.count }
    /// 个人应补差额，单位为分。
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
                let payment = ProfileRules.monthlyContribution(salaryCents: base, rateBasisPoints: rate)
                let expected = wage.flatMap { wage in limit.map { min(max(wage, $0.lowerCents), $0.upperCents) } }
                let missing: HousingShortfallMonth.Missing? = wage == nil ? .salary
                    : limit == nil ? .limit : base == nil ? .base
                    : rate == nil || rate == 0 ? .rate : nil
                let gap = expected.flatMap { expected in base.map { max(expected - $0, 0) } }
                let amount = missing == nil ? ProfileRules.monthlyContribution(salaryCents: gap, rateBasisPoints: rate) : nil
                results.append(HousingShortfallMonth(
                    employmentID: job.id, month: month, wageCents: wage,
                    expectedBaseCents: expected, recordedBaseCents: base,
                    rateBasisPoints: rate, configuredPaymentCents: payment,
                    limitEvidence: limit?.evidence,
                    personalShortfallCents: amount, missing: missing
                ))
                guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
                month = next
            }
            return HousingShortfallCompany(job: job, months: results.reversed())
        }
    }
}
