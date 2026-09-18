import Foundation

@main struct ExpectedExpenseTests {
    @MainActor static func main() throws {
        let date = ProfileRules.date(2026, 9, 1)
        let mortgage = LiabilityAccount()
        mortgage.name = "房贷"
        let snapshot = LiabilitySnapshot(balanceDate: ProfileRules.date(2026, 8, 31), mortgages: [.init(principal: 12000_00, annualPercent: 0, months: 12, nextDate: date, dueDay: 10)])
        mortgage.snapshotData = try JSONEncoder().encode(snapshot)
        precondition(ExpectedExpenseRules.total(expenses: [], liabilities: [mortgage], in: date) == 1000_00)
        let expense = RecurringExpense()
        expense.planData = try JSONEncoder().encode(ExpensePlan(name: "生活费", amount: 3000_00, start: date))
        precondition(ExpectedExpenseRules.total(expenses: [expense], liabilities: [mortgage, mortgage], in: date) == 4000_00)
        precondition(ExpectedExpenseRules.total(expenses: [], liabilities: [mortgage], in: ProfileRules.date(2027, 9, 1)) == 0)
        let card = LiabilityAccount(); card.kindRaw = "creditCard"
        let installment = CardInstallment(name: "分期", principal: 1200_00, months: 12, nextDate: date, dueDay: 10)
        card.snapshotData = try JSONEncoder().encode(LiabilitySnapshot(balanceDate: ProfileRules.date(2026, 8, 31), cardTotal: 2000_00, billDue: 200_00, billDate: ProfileRules.date(2026, 9, 10), installments: [installment]))
        precondition(ExpectedExpenseRules.repayment(card, in: date) == 200_00)
        precondition(ExpectedExpenseRules.total(expenses: [expense], liabilities: [mortgage, card], in: date) == 4200_00)
        card.snapshotData = try JSONEncoder().encode(LiabilitySnapshot(balanceDate: ProfileRules.date(2026, 8, 31), cardTotal: 2000_00, installments: [installment]))
        precondition(ExpectedExpenseRules.missingBills([card]))
        card.snapshotData = Data([0])
        precondition(ExpectedExpenseRules.total(expenses: [expense], liabilities: [mortgage, card], in: date) == nil)
        precondition(ExpectedExpenseRules.total(expenses: [], liabilities: [], in: date) == 0)
        print("ExpectedExpenseTests passed: mortgage-only, mixed totals, deduplication, card bill coverage, missing/corrupt data, end dates")
    }
}
