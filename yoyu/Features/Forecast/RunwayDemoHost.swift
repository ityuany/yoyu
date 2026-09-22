import SwiftUI
import SwiftData

@MainActor private final class RunwayDemoData {
    let container: ModelContainer
    let clock = CareerClock()
    init() {
        let schema = Schema([UserProfile.self, WorkdayOverride.self, Employment.self, SalaryStage.self, StockHolding.self, LiabilityAccount.self, RecurringExpense.self, RunwaySettings.self])
        container = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        clock.now = ProfileRules.date(2026, 9, 22)
        let p = UserProfile()
        p.cashCents = 80_000_00
        p.stockCents = 120_000_00
        p.investmentCents = 200_000_00
        p.investmentRegistrationDate = ProfileRules.date(2026, 9, 22)
        p.investmentAnnualReturnBasisPoints = 300
        let job = Employment()
        job.name = "示例公司"
        job.start = ProfileRules.date(2020, 1, 1)
        job.severanceData = try! JSONEncoder().encode(SeveranceSettings())
        let stage = SalaryStage()
        stage.employmentID = job.id
        stage.effectiveDate = job.start
        stage.salaryCents = 20_000_00
        var expense = ExpensePlan()
        expense.name = "生活开支"
        expense.amount = 12_000_00
        expense.start = ProfileRules.date(2026, 1, 1)
        let record = RecurringExpense()
        record.planData = try! JSONEncoder().encode(expense)
        container.mainContext.insert(p)
        container.mainContext.insert(job)
        container.mainContext.insert(stage)
        container.mainContext.insert(record)
        try! container.mainContext.save()
        for mode in RunwayMode.allCases where !ProcessInfo.processInfo.arguments.contains("--runway-unconfigured") {
            let plan = RunwayPlan(mode: mode, lossDate: ProfileRules.date(2026, 10, 1), returnDate: ProfileRules.date(2027, 4, 1), salary: 9_000_00, payday: 10, flexible: 2_000_00, flexibleDay: 15)
            try! RunwayStore.save(plan, records: [], context: container.mainContext)
        }
    }
}

struct RunwayDemoHost: View {
    @State private var data = RunwayDemoData()
    @State private var navigation = AppNavigation()
    var body: some View {
        RunwayView(isExample: true)
            .modelContainer(data.container)
            .environment(data.clock)
            .environment(navigation)
            .environment(\.locale, Locale(identifier: "zh_CN"))
    }
}
