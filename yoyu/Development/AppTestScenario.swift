#if DEBUG
import SwiftUI

/// 启动参数对应的独立测试场景，按原有优先级选择第一个匹配项。
enum AppTestScenario: CaseIterable {
    case runwayDemo, employmentPayday, severance, expense, expenseDedupe
    case financialExport, socialLimits, pensionShortfall, housingShortfall, mortgage

    private var argument: String {
        switch self {
        case .runwayDemo: "--runway-demo"
        case .employmentPayday: "--employment-payday-ui-test"
        case .severance: "--severance-ui-test"
        case .expense: "--expense-ui-test"
        case .expenseDedupe: "--expense-dedupe-ui-test"
        case .financialExport: "--financial-export-ui-test"
        case .socialLimits: "--social-limits-ui-test"
        case .pensionShortfall: "--pension-shortfall-ui-test"
        case .housingShortfall: "--housing-shortfall-ui-test"
        case .mortgage: "--mortgage-ui-test"
        }
    }

    static var current: Self? {
        let arguments = ProcessInfo.processInfo.arguments
        return allCases.first { arguments.contains($0.argument) }
    }

    @ViewBuilder var content: some View {
        switch self {
        case .runwayDemo: RunwayDemoHost()
        case .employmentPayday: EmploymentPaydayTestHost()
        case .severance: SeveranceTestHost()
        case .expense:
            NavigationStack { ExpenseExampleView() }
                .environment(CareerClock())
                .environment(\.locale, Locale(identifier: "zh_CN"))
        case .expenseDedupe:
            NavigationStack { ExpenseExampleView(showsDuplicateExample: true) }
                .environment(CareerClock())
                .environment(\.locale, Locale(identifier: "zh_CN"))
        case .financialExport: FinancialExportTestHost()
        case .socialLimits: SocialInsuranceLimitsTestHost()
        case .pensionShortfall: PensionShortfallTestHost()
        case .housingShortfall: HousingShortfallTestHost()
        case .mortgage:
            NavigationStack { LiabilityExampleView() }
                .environment(CareerClock())
                .environment(\.locale, Locale(identifier: "zh_CN"))
        }
    }
}
#endif
