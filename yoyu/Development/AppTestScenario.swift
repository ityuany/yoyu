#if DEBUG
import SwiftUI

/// 启动参数对应的独立测试场景，按原有优先级选择第一个匹配项。
enum AppTestScenario: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    /// 调试目录与启动参数入口共用场景定义，避免新增场景时遗漏菜单。
    var title: String {
        switch self {
        case .theme: "整体配色与分析概览"
        case .runwayDemo: "生存时长测算"
        case .employmentPayday: "发薪日与收入"
        case .severance: "离职补偿"
        case .expense: "日常开支"
        case .expenseDedupe: "开支重复关联"
        case .financialExport: "财务导出"
        case .socialLimits: "养老与公积金上下限"
        case .pensionShortfall: "养老保险少缴分析"
        case .housingShortfall: "公积金少缴分析"
        case .mortgage: "房贷与负债"
        }
    }
    case theme
    case runwayDemo, employmentPayday, severance, expense, expenseDedupe
    case financialExport, socialLimits, pensionShortfall, housingShortfall, mortgage

    private var argument: String {
        switch self {
        case .theme: "--theme-ui-test"
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
        case .theme: ThemeTestHost()
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
