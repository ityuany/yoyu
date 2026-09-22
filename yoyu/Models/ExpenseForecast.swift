import Foundation

struct ExpenseForecastMonth: Identifiable {
    let date: Date
    let daily: Int64?
    let repayment: Int64?
    var id: Date { date }
    var total: Int64? {
        guard let daily, let repayment else { return nil }
        return LiabilityRules.sum([daily, repayment])
    }
}

enum ExpenseForecast {
    static func months(expenses: [RecurringExpense], liabilities: [LiabilityAccount], after date: Date, count: Int, workBreaks: [ExpenseWorkBreak] = []) -> [ExpenseForecastMonth] {
        let accounts = LiabilityRules.accounts(liabilities)
        return (1...max(1, count)).map { offset in
            let month = ExpenseRules.calendar.date(byAdding: .month, value: offset, to: ExpenseRules.month(date))!
            let repayments = accounts.map { ExpectedExpenseRules.repayment($0, in: month) }
            return ExpenseForecastMonth(date: month, daily: ExpenseRules.total(expenses, in: month, workBreaks: workBreaks),
                repayment: repayments.contains(where: { $0 == nil }) ? nil : LiabilityRules.sum(repayments.compactMap { $0 }))
        }
    }
    static func total(_ months: [ExpenseForecastMonth]) -> Int64? {
        guard months.allSatisfy({ $0.total != nil }) else { return nil }
        return LiabilityRules.sum(months.compactMap(\.total))
    }
}
