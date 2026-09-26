import Foundation
import SwiftData

@main struct HousingShortfallTests {
    @MainActor static func main() {
        let job = Employment()
        job.start = ProfileRules.date(2024, 1, 1)
        job.end = ProfileRules.date(2025, 8, 31)
        let salary = SalaryStage()
        salary.employmentID = job.id
        salary.effectiveDate = job.start
        salary.salaryCents = 1_000_000
        salary.bonusCents = 2_400_000
        salary.bonusMonth = 12
        let raise = SalaryStage()
        raise.employmentID = job.id
        raise.effectiveDate = ProfileRules.date(2025, 4, 1)
        raise.salaryCents = 1_300_000
        let reduction = SalaryStage()
        reduction.employmentID = job.id
        reduction.effectiveDate = ProfileRules.date(2025, 7, 1)
        reduction.salaryCents = 300_000
        let stage = ContributionStage()
        stage.employmentID = job.id
        stage.effectiveMonth = job.start!
        stage.housingBaseCents = 800_000
        stage.housingBasisPoints = 1_200
        let limit = HousingFundLimit()
        limit.effectiveMonth = job.start!
        limit.lowerCents = 500_000
        limit.upperCents = 1_100_000
        let reports = HousingShortfallRules.calculate(
            jobs: [job], salaries: [salary, raise, reduction], contributions: [stage], limits: [limit],
            through: ProfileRules.date(2025, 9, 1)
        )
        precondition(reports.count == 1 && reports[0].months.count == 20)
        let months = reports[0].months
        let june = months.first { ProfileRules.calendar.isDate($0.month, equalTo: ProfileRules.date(2025, 6, 1), toGranularity: .month) }!
        let july = months.first { ProfileRules.calendar.isDate($0.month, equalTo: ProfileRules.date(2025, 7, 1), toGranularity: .month) }!
        let march = months.first { ProfileRules.calendar.isDate($0.month, equalTo: ProfileRules.date(2025, 3, 1), toGranularity: .month) }!
        precondition(march.wageCents == 1_000_000 && march.expectedBaseCents == 1_000_000)
        precondition(june.wageCents == 1_300_000 && june.expectedBaseCents == 1_100_000)
        precondition(june.personalShortfallCents == 36_000)
        precondition(july.wageCents == 300_000 && july.expectedBaseCents == 500_000)
        precondition(july.personalShortfallCents == 0)
        stage.housingBasisPoints = nil
        let missing = HousingShortfallRules.calculate(
            jobs: [job], salaries: [salary, raise, reduction], contributions: [stage], limits: [limit],
            through: ProfileRules.date(2025, 9, 1)
        )[0]
        precondition(missing.missingCount == 20 && missing.personalShortfallCents == 0)
        print("HousingShortfallTests passed")
    }
}
