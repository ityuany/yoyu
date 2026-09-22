import Foundation

/// A read-only aggregation of existing plans. Never creates another liability or payment.
enum ExpectedExpenseRules {
    static func repayment(_ account: LiabilityAccount, in month: Date, from lowerBound: Date? = nil, through upperBound: Date? = nil) -> Int64? {
        guard let snapshot = account.snapshot, let kind = account.kind,
              LiabilityRules.error(snapshot, kind: kind) == nil else { return nil }
        let first = ExpenseRules.month(month)
        let payments = LiabilityRules.payments(snapshot, kind: kind, on: first)
            .filter { payment in
                let day = ExpenseRules.calendar.startOfDay(for: payment.date)
                return ExpenseRules.month(day) == first
                    && (lowerBound.map { day >= ExpenseRules.calendar.startOfDay(for: $0) } ?? true)
                    && (upperBound.map { day <= ExpenseRules.calendar.startOfDay(for: $0) } ?? true)
            }
        return LiabilityRules.sum(payments.map(\.total))
    }
    static func total(expenses: [RecurringExpense], liabilities: [LiabilityAccount], in month: Date, workBreaks: [ExpenseWorkBreak] = []) -> Int64? {
        guard let daily = ExpenseRules.total(expenses, in: month, workBreaks: workBreaks) else { return nil }
        var amounts = [daily]
        for account in LiabilityRules.accounts(liabilities) {
            guard let amount = repayment(account, in: month) else { return nil }
            amounts.append(amount)
        }
        return LiabilityRules.sum(amounts)
    }
    static func missingBills(_ liabilities: [LiabilityAccount]) -> Bool {
        LiabilityRules.accounts(liabilities).contains {
            $0.kind == .creditCard && $0.snapshot?.fixedInstallmentsOnly != true && $0.snapshot?.billDue == nil
        }
    }
}
