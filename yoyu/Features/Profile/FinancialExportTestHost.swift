#if DEBUG
import SwiftUI
import SwiftData

struct FinancialExportTestHost: View {
    private let container: ModelContainer = {
        let schema = Schema([UserProfile.self, Employment.self, SalaryStage.self, ContributionStage.self, SocialInsuranceMonth.self, StockHolding.self, LiabilityAccount.self, RecurringExpense.self])
        let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let profile = UserProfile()
        profile.cashCents = 100000_00
        profile.careerMigrated = true
        profile.stockMigrated = true
        container.mainContext.insert(profile)
        try! container.mainContext.save()
        return container
    }()

    var body: some View {
        NavigationStack {
            ProfileMenuView(summary: "测试资料", syncStatus: "独立测试数据")
                .dashboardTabRoot(title: "我的")
        }
        .modelContainer(container)
    }
}
#endif
