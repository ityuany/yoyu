import SwiftUI
import SwiftData
import UIKit

#if DEBUG
struct EmploymentPaydayTestHost: View {
    private let clock: CareerClock = {
        let clock = CareerClock()
        clock.now = ProfileRules.date(2026, 9, 26)
        return clock
    }()
    private let container: ModelContainer = {
        let schema = Schema([Employment.self, SalaryStage.self, BonusPayment.self, ContributionStage.self, SocialInsuranceLimit.self, StockHolding.self, UserProfile.self])
        let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let job = Employment()
        job.name = "发薪日测试企业"
        job.start = ProfileRules.date(2024, 1, 1)
        container.mainContext.insert(job)
        for year in [2024, 2025] {
            let stage = SalaryStage()
            stage.employmentID = job.id
            stage.effectiveDate = ProfileRules.date(year, 1, 1)
            stage.salaryCents = 2_000_000
            container.mainContext.insert(stage)
        }
        try! container.mainContext.save()
        return container
    }()
    var body: some View {
        NavigationStack {
            CareerView(destination: .history)
                .navigationDestination(for: CareerDestination.self) { CareerView(destination: $0) }
        }
            .modelContainer(container)
            .environment(clock)
            .environment(AppNavigation())
            .environment(\.locale, Locale(identifier: "zh_CN"))
    }
}
#endif
