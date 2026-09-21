import Foundation

@main struct FinancialMarkdownTests {
    @MainActor static func main() throws {
        let now = ProfileRules.date(2026, 9, 22)
        let profile = UserProfile()
        profile.cashCents = 100000_00
        profile.stockMigrated = true
        let holding = StockHolding()
        holding.name = "公司\n# 伪标题"
        holding.initialSharesHundredths = 100_00
        holding.priceCents = 10_00
        holding.grantData = try JSONEncoder().encode([EquityGrant(name: "授予", date: now, shares: 50_00, installments: [.init(date: ProfileRules.date(2027, 1, 1), shares: 50_00)])])
        let liability = LiabilityAccount()
        liability.name = "房贷"
        liability.snapshotData = try JSONEncoder().encode(LiabilitySnapshot(balanceDate: now, mortgages: [.init(principal: 12000_00, annualPercent: 0, months: 12, nextDate: ProfileRules.date(2026, 10, 1))]))
        let expense = RecurringExpense()
        expense.planData = try JSONEncoder().encode(ExpensePlan(name: "生活费", amount: 3000_00, start: now))
        func render(_ debts: [LiabilityAccount]) -> String {
            FinancialMarkdown.make(profiles: [profile], jobs: [], stages: [], holdings: [holding, holding], liabilities: debts, expenses: [expense, expense], now: now)
        }
        let report = render([liability, liability])
        precondition(report.contains("已记录资产合计：¥101,000.00"), report)
        precondition(report.contains("已记录净值：¥89,000.00"))
        precondition(report.contains("| 2026 年 10 月 | ¥3,000.00 | ¥1,000.00 | ¥4,000.00 |"))
        precondition(report.contains("2027-01-01：50 股，待归属"))
        precondition(!report.contains("\n# 伪标题"))
        precondition(report.components(separatedBy: "### 公司").count == 2)
        precondition(render([]).contains("已记录净值：未记录或无法计算"))
        liability.snapshotData = Data([0])
        precondition(render([liability]).contains("已记录负债合计：未记录或无法计算"))
        holding.priceIsConfigured = false
        precondition(render([]).contains("已记录资产合计：未记录或无法计算"))
        let empty = FinancialMarkdown.make(profiles: [], jobs: [], stages: [], holdings: [], liabilities: [], expenses: [], now: now)
        precondition(empty.contains("未记录负债，不能据此认定无负债"))
        print("FinancialMarkdownTests passed")
    }
}
