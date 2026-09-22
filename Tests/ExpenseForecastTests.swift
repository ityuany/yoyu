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
        var livingPlan = living.plan!
        livingPlan.pausesDuringWorkBreak = true
        living.planData = try JSONEncoder().encode(livingPlan)
        let breaks = [ExpenseWorkBreak(start: ProfileRules.date(2026, 10, 1), end: ProfileRules.date(2026, 11, 30))]
        let scenario = ExpenseForecast.months(expenses: [living, yearly], liabilities: [mortgage], after: ProfileRules.date(2026, 9, 22), count: 12, workBreaks: breaks)
        precondition(scenario[0].daily == 0 && scenario[0].repayment == 1000_00)
        precondition(scenario[1].total == 1000_00 && scenario[2].total == 9000_00)
        precondition(ExpenseForecast.total(scenario) == 38000_00)
        precondition(ExpectedExpenseRules.total(expenses: [living, yearly], liabilities: [mortgage], in: scenario[0].date, workBreaks: breaks) == scenario[0].total)
        precondition(ExpenseForecast.total(ExpenseForecast.months(expenses: [living, yearly], liabilities: [mortgage], after: ProfileRules.date(2026, 9, 22), count: 12)) == 44000_00)
        yearly.planData = Data([0])
        precondition(ExpenseForecast.total(ExpenseForecast.months(expenses: [living, yearly], liabilities: [], after: Date(), count: 60)) == nil)
        print("ExpenseForecastTests passed")
    }
}
