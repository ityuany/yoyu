import SwiftUI
import SwiftData

#if DEBUG
struct SeveranceTestHost: View {
    private let container: ModelContainer
    private let clock = CareerClock()

    init() {
        let schema = Schema([UserProfile.self, WorkdayOverride.self, Employment.self, SalaryStage.self, BonusPayment.self, ContributionStage.self,
                             StockHolding.self, LiabilityAccount.self, RecurringExpense.self, RunwaySettings.self])
        container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        clock.now = ProfileRules.calendar.date(from: DateComponents(year: 2026, month: 9, day: 22))!
        let job = Employment()
        job.name = "补偿测试企业"
        job.start = ProfileRules.calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        let salary = SalaryStage()
        salary.employmentID = job.id
        salary.effectiveDate = job.start
        salary.salaryCents = 2_000_000
        container.mainContext.insert(job)
        container.mainContext.insert(salary)
        try! container.mainContext.save()
    }

    var body: some View {
        WealthView()
            .modelContainer(container)
            .environment(clock)
            .environment(AppNavigation())
            .environment(\.locale, Locale(identifier: "zh_CN"))
    }
}
#endif
