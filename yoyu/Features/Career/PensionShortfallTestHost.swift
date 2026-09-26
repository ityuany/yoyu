import SwiftUI
import SwiftData

#if DEBUG
struct PensionShortfallTestHost: View {
    private let container: ModelContainer? = {
        do {
            let schema = Schema([Employment.self, SalaryStage.self, BonusPayment.self, ContributionStage.self, SocialInsuranceLimit.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            let job = Employment()
            job.name = "测试企业"
            job.start = ProfileRules.date(2024, 1, 1)
            job.end = ProfileRules.date(2024, 3, 31)
            context.insert(job)
            let salary = SalaryStage()
            salary.employmentID = job.id
            salary.effectiveDate = job.start
            salary.salaryCents = 1_000_000
            context.insert(salary)
            let contribution = ContributionStage()
            contribution.employmentID = job.id
            contribution.effectiveMonth = ProfileRules.date(2024, 1, 1)
            contribution.pensionBaseCents = 800_000
            contribution.pensionBasisPoints = 800
            context.insert(contribution)
            let matchingContribution = ContributionStage()
            matchingContribution.employmentID = job.id
            matchingContribution.effectiveMonth = ProfileRules.date(2024, 3, 1)
            matchingContribution.pensionBaseCents = 1_000_000
            matchingContribution.pensionBasisPoints = 800
            context.insert(matchingContribution)
            let limit = SocialInsuranceLimit()
            limit.effectiveMonth = ProfileRules.date(2024, 1, 1)
            limit.lowerCents = 500_000
            limit.upperCents = 2_000_000
            context.insert(limit)
            let longJob = Employment()
            longJob.name = "长期企业"
            longJob.start = ProfileRules.date(2024, 1, 1)
            longJob.end = ProfileRules.date(2024, 5, 31)
            context.insert(longJob)
            let longSalary = SalaryStage()
            longSalary.employmentID = longJob.id
            longSalary.effectiveDate = longJob.start
            longSalary.salaryCents = 1_000_000
            context.insert(longSalary)
            let longContribution = ContributionStage()
            longContribution.employmentID = longJob.id
            longContribution.effectiveMonth = ProfileRules.date(2024, 1, 1)
            longContribution.pensionBaseCents = 900_000
            longContribution.pensionBasisPoints = 800
            context.insert(longContribution)
            try context.save()
            return container
        } catch { return nil }
    }()

    var body: some View {
        Group {
            if let container {
                let primaryJob = (try? container.mainContext.fetch(FetchDescriptor<Employment>()))?.first { $0.name == "测试企业" }
                NavigationStack {
                    List {
                        NavigationLink("疑似少缴") { PensionShortfallView() }
                            .accessibilityIdentifier("pension.shortfall")
                        if let primaryJob {
                            NavigationLink("逐月缴纳") { PensionMonthlyPaymentsView(job: primaryJob) }
                                .accessibilityIdentifier("pension.monthlyPayments")
                        }
                    }
                    .navigationTitle("养老保险")
                }
                .modelContainer(container)
                .environment(CareerClock())
                .environment(\.locale, Locale(identifier: "zh_CN"))
            } else {
                ContentUnavailableView("测试资料不可用", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
#endif
