import Foundation
import SwiftData

@main struct PensionShortfallTests {
    @MainActor static func main() {
        let job = Employment()
        job.start = ProfileRules.date(2024, 1, 1)
        job.end = ProfileRules.date(2025, 12, 31)
        let salary = SalaryStage()
        salary.employmentID = job.id
        salary.effectiveDate = job.start
        salary.salaryCents = 1_000_000
        salary.bonusCents = 2_400_000
        salary.bonusMonth = 12
        let actual2024 = ContributionStage()
        actual2024.employmentID = job.id
        actual2024.effectiveMonth = ProfileRules.date(2024, 1, 1)
        actual2024.pensionBaseCents = 800_000
        let actual2025 = ContributionStage()
        actual2025.employmentID = job.id
        actual2025.effectiveMonth = ProfileRules.date(2025, 1, 1)
        actual2025.pensionBaseCents = 900_000
        let limit2024 = SocialInsuranceLimit()
        limit2024.city = "用户配置地区"
        limit2024.effectiveMonth = ProfileRules.date(2024, 1, 1)
        limit2024.lowerCents = 500_000
        limit2024.upperCents = 2_000_000
        let limit2025 = SocialInsuranceLimit()
        limit2025.city = "用户配置地区"
        limit2025.effectiveMonth = ProfileRules.date(2025, 1, 1)
        limit2025.lowerCents = 500_000
        limit2025.upperCents = 1_100_000
        let proof = SocialInsuranceMonth()
        proof.employmentID = job.id
        proof.month = ProfileRules.date(2025, 6, 1)
        proof.pensionBaseCents = 1_100_000
        let reports = PensionShortfallRules.calculate(
            jobs: [job], salaries: [salary], contributions: [actual2024, actual2025],
            proofMonths: [proof], limits: [limit2024, limit2025], through: ProfileRules.date(2026, 1, 1)
        )
        precondition(reports.count == 1)
        let company = reports[0]
        precondition(company.months.count == 24 && company.missingCount == 0)
        precondition(company.personalShortfallCents == 368_000)
        precondition(company.averageMonthlyShortfallCents == 15_333)
        precondition(abs((company.shortfallRate ?? 0) - 46.0 / 252.0) < 0.000001)
        let january2024 = company.months.first { ProfileRules.calendar.isDate($0.month, equalTo: ProfileRules.date(2024, 1, 1), toGranularity: .month) }!
        precondition(january2024.expectedBaseCents == 1_000_000)
        precondition(january2024.personalShortfallCents == 16_000)
        let january2025 = company.months.first { ProfileRules.calendar.isDate($0.month, equalTo: ProfileRules.date(2025, 1, 1), toGranularity: .month) }!
        precondition(january2025.wageCents == 1_200_000)
        precondition(january2025.expectedBaseCents == 1_100_000)
        precondition(january2025.personalShortfallCents == 16_000)
        let june2025 = company.months.first { ProfileRules.calendar.isDate($0.month, equalTo: proof.month, toGranularity: .month) }!
        precondition(june2025.baseFromProof && june2025.personalShortfallCents == 0)
        salary.salaryCents = nil
        let missing = PensionShortfallRules.calculate(
            jobs: [job], salaries: [salary], contributions: [actual2024], proofMonths: [],
            limits: [limit2024, limit2025], through: ProfileRules.date(2026, 1, 1)
        )[0]
        precondition(missing.missingCount == 24 && missing.personalShortfallCents == 0)
        salary.salaryCents = 300_000
        actual2024.pensionBaseCents = 400_000
        let floor = PensionShortfallRules.calculate(
            jobs: [job], salaries: [salary], contributions: [actual2024], proofMonths: [],
            limits: [limit2024], through: ProfileRules.date(2024, 2, 15)
        )[0]
        precondition(floor.months.count == 1)
        precondition(floor.months[0].expectedBaseCents == 500_000)
        precondition(floor.months[0].personalShortfallCents == 8_000)
        print("PensionShortfallTests passed")
    }
}
