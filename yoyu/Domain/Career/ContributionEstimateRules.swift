import Foundation

enum ContributionEstimateRules {
    static func calculate(_ records: [ContributionStage], for job: Employment, kind: ContributionKind, through date: Date) -> ContributionEstimate? {
        guard let jobStart = job.start else { return nil }
        let calendar = ProfileRules.calendar
        let first = CareerRules.monthStart(jobStart)
        let last = CareerRules.monthStart(min(job.end ?? date, date))
        guard first <= last else { return nil }
        let stages = CareerRules.contributions(records, for: job, kind: kind)
        var month = first
        var amount: Int64 = 0
        var covered = 0
        while month <= last {
            if let stage = stages.first(where: { $0.effectiveMonth <= month }),
               let monthly = ProfileRules.monthlyContribution(salaryCents: kind.base(stage), rateBasisPoints: kind.rate(stage)) {
                let (total, totalOverflow) = amount.addingReportingOverflow(monthly)
                guard !totalOverflow else { return nil }
                amount = total
                covered += 1
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { return nil }
            month = next
        }
        return covered == 0 ? nil : ContributionEstimate(amountCents: amount, coveredMonths: covered)
    }
}
