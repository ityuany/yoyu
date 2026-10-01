import SwiftUI
import SwiftData

#if DEBUG
struct HousingShortfallTestHost: View {
    private let container: ModelContainer? = {
        do {
            let schema = Schema([Employment.self, SalaryStage.self, ContributionStage.self, HousingFundLimit.self])
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
            contribution.effectiveMonth = job.start!
            contribution.housingBaseCents = 800_000
            contribution.housingBasisPoints = 1_200
            context.insert(contribution)
            let matchingContribution = ContributionStage()
            matchingContribution.employmentID = job.id
            matchingContribution.effectiveMonth = ProfileRules.date(2024, 3, 1)
            matchingContribution.housingBaseCents = 1_000_000
            matchingContribution.housingBasisPoints = 1_200
            context.insert(matchingContribution)
            let limit = HousingFundLimit()
            limit.effectiveMonth = job.start!
            limit.lowerCents = 500_000
            limit.upperCents = 2_000_000
            context.insert(limit)
            try context.save()
            return container
        } catch { return nil }
    }()

    var body: some View {
        Group {
            if let container {
                let primaryJob = (try? container.mainContext.fetch(FetchDescriptor<Employment>()))?.first
                NavigationStack {
                    List {
                        NavigationLink("疑似少缴") { HousingShortfallView() }
                            .accessibilityIdentifier("housing.shortfall")
                        if let primaryJob {
                            NavigationLink("企业公积金") { ContributionOverview(job: primaryJob, kind: .housing) }
                                .accessibilityIdentifier("housing.companyOverview")
                            NavigationLink("逐月缴纳") { HousingMonthlyPaymentsView(job: primaryJob) }
                                .accessibilityIdentifier("housing.monthlyPayments")
                        }
                    }
                    .navigationTitle("住房公积金")
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
