import Foundation

@main struct ExpenseForecastTests {
    @MainActor static func main() throws {
        let living = RecurringExpense()
        living.planData = try JSONEncoder().encode(ExpensePlan(name: "生活费", amount: 3000_00, start: ProfileRules.date(2026, 9, 1)))
        let yearly = RecurringExpense()
        yearly.planData = try JSONEncoder().encode(ExpensePlan(name: "年费", amount: 6000_00, frequency: .yearly, start: ProfileRules.date(2026, 12, 10), spreadAcrossMonth: false, dueDay: 10))
        let mortgage = LiabilityAccount()
        mortgage.snapshotData = try JSONEncoder().encode(LiabilitySnapshot(balanceDate: ProfileRules.date(2026, 9, 1), mortgages: [.init(principal: 2000_00, annualPercent: 0, months: 2, nextDate: ProfileRules.date(2026, 10, 10), dueDay: 10)]))
        let months = ExpenseForecast.months(expenses: [living, yearly], liabilities: [mortgage], after: ProfileRules.date(2026, 9, 22), count: 12)
        precondition(months.count == 12)
        precondition(months[0].date == ExpenseRules.month(ProfileRules.date(2026, 10, 1)))
        precondition(months[11].date == ExpenseRules.month(ProfileRules.date(2027, 9, 1)))
        precondition(months[0].total == 4000_00)
        precondition(months[2].total == 9000_00)
        precondition(months[3].repayment == 0)
        precondition(ExpenseForecast.total(months) == 44000_00)
        yearly.planData = Data([0])
        precondition(ExpenseForecast.total(ExpenseForecast.months(expenses: [living, yearly], liabilities: [], after: Date(), count: 60)) == nil)
        print("ExpenseForecastTests passed")
    }
}
