#if DEBUG
import SwiftUI
import SwiftData

/// 使用独立内存账本展示真实页面，支持启动参数及调试菜单两种入口。
struct ThemeTestHost: View {
    private let container: ModelContainer
    private let appearance: ColorScheme

    init(appearance: ColorScheme? = nil, largeValues: Bool? = nil) {
        let schema = AppModelSchema.schema
        container = try! ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        ])
        self.appearance = appearance ?? (ProcessInfo.processInfo.arguments.contains("--theme-dark") ? .dark : .light)
        let profile = UserProfile()
        profile.birthYear = 1990
        profile.birthMonth = 1
        profile.gender = "男"
        profile.careerMigrated = true
        profile.cashCents = 6_865_000
        profile.investmentCents = 18_000_000
        profile.investmentRegistrationDate = ProfileRules.date(2026, 9, 22)
        profile.investmentAnnualReturnBasisPoints = 300
        let job = Employment()
        job.name = "配色示例企业"
        job.start = ProfileRules.date(2020, 1, 1)
        let salary = SalaryStage()
        salary.employmentID = job.id
        salary.effectiveDate = job.start
        let largeValues = largeValues ?? ProcessInfo.processInfo.arguments.contains("--analysis-large-values")
        salary.salaryCents = largeValues ? 50_000_000 : 1_850_000
        let contribution = ContributionStage()
        contribution.employmentID = job.id
        contribution.effectiveMonth = job.start!
        contribution.pensionBaseCents = largeValues ? 20_000_000 : 1_500_000
        contribution.pensionBasisPoints = 800
        contribution.housingBaseCents = largeValues ? 20_000_000 : 1_400_000
        contribution.housingBasisPoints = 1200
        let pensionLimit = SocialInsuranceLimit()
        pensionLimit.effectiveMonth = job.start!
        pensionLimit.lowerCents = 300_000
        pensionLimit.upperCents = largeValues ? 50_000_000 : 3_000_000
        let housingLimit = HousingFundLimit()
        housingLimit.effectiveMonth = job.start!
        housingLimit.lowerCents = 300_000
        housingLimit.upperCents = largeValues ? 50_000_000 : 3_000_000
        container.mainContext.insert(contribution)
        container.mainContext.insert(pensionLimit)
        container.mainContext.insert(housingLimit)
        var expensePlan = ExpensePlan()
        expensePlan.name = "示例生活开支"
        expensePlan.amount = 1_200_000
        expensePlan.start = ProfileRules.date(2026, 1, 1)
        let expense = RecurringExpense()
        expense.apply(expensePlan)
        container.mainContext.insert(expense)
        container.mainContext.insert(profile)
        container.mainContext.insert(job)
        container.mainContext.insert(salary)
        try! container.mainContext.save()
    }

    var body: some View {
        ContentView()
            .modelContainer(container)
            .environment(SyncMonitor())
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .preferredColorScheme(appearance)
    }
}
#endif
