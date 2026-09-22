import Foundation
import SwiftData

@main struct RunwayTests {
    @MainActor static func main() async throws {
        let c = ProfileRules.calendar
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date { c.startOfDay(for: ProfileRules.date(y, m, d)) }
        let today = date(2026, 1, 1)
        let p = UserProfile()
        p.cashCents = 100_00
        p.stockCents = 100_00
        p.investmentCents = 100_00
        p.investmentRegistrationDate = today
        p.investmentAnnualReturnBasisPoints = 0
        let job = Employment()
        job.start = date(2020, 1, 1)
        job.salaryPaymentDay = 10
        job.severanceData = try JSONEncoder().encode(SeveranceSettings())
        let stage = SalaryStage()
        stage.employmentID = job.id
        stage.effectiveDate = job.start
        stage.salaryCents = 0
        var expense = ExpensePlan()
        expense.name = "固定支出"
        expense.amount = 250_00
        expense.start = today
        expense.spreadAcrossMonth = false
        expense.dueDay = 1
        let record = RecurringExpense()
        record.planData = try JSONEncoder().encode(expense)
        let employed = RunwayPlan()
        let result = await RunwayEngine.calculate(plan: employed, profile: p, stocks: [], jobs: [job], stages: [stage], expenses: [record], liabilities: [], today: today, years: 2)
        precondition(result.issue == nil, result.issue ?? "")
        precondition(result.failure == date(2026, 2, 1))
        let jan = result.points.first { $0.date == date(2026, 1, 31) }!
        precondition(jan.cash == 0 && jan.stock == 0 && jan.investment == 50_00 && jan.redeemed == 50_00)
        precondition(result.duration == "1 个月零 0 天")
        var loss = RunwayPlan(mode: .indefinite, lossDate: date(2026, 3, 1))
        let before = await RunwayEngine.calculate(plan: loss, profile: p, stocks: [], jobs: [job], stages: [stage], expenses: [record], liabilities: [], today: today, years: 2)
        precondition(before.failure == date(2026, 2, 1) && before.opening == nil)
        loss.lossDate = today
        p.cashCents = 0; p.stockCents = 0; p.investmentCents = 0
        stage.salaryCents = 100_00
        let compensated = await RunwayEngine.calculate(plan: loss, profile: p, stocks: [], jobs: [job], stages: [stage], expenses: [record], liabilities: [], today: today, years: 2)
        precondition(compensated.compensation == 700_00)
        precondition(compensated.opening?.total == 700_00)
        precondition(compensated.failure == date(2026, 3, 1))
        precondition(RunwayEngine.validation(RunwayPlan(mode: .temporary, lossDate: today, returnDate: today, salary: 1), today: today) != nil)
        precondition(RunwayEngine.validation(RunwayPlan(mode: .indefinite, lossDate: date(2025, 12, 31)), today: today) != nil)
        let missing = await RunwayEngine.calculate(plan: employed, profile: p, stocks: [], jobs: [job], stages: [stage], expenses: [], liabilities: [], today: today, years: 1)
        precondition(missing.issue != nil)
        // Salary arrives on the configured day before that day's payment.
        p.cashCents = 0
        expense.dueDay = 10; expense.amount = 100_00
        record.planData = try JSONEncoder().encode(expense)
        let salary = await RunwayEngine.calculate(plan: employed, profile: p, stocks: [], jobs: [job], stages: [stage], expenses: [record], liabilities: [], today: today, years: 1)
        precondition(salary.failure == nil)
        // Duplicated accounts are deduplicated; remaining debt is paid on its dates.
        p.cashCents = 100_00
        stage.salaryCents = 0
        let loan = LiabilityAccount()
        loan.snapshotData = try JSONEncoder().encode(LiabilitySnapshot(balanceDate: date(2025, 12, 31), mortgages: [.init(principal: 200_00, annualPercent: 0, months: 2, nextDate: today, dueDay: 1)]))
        let borrowed = await RunwayEngine.calculate(plan: employed, profile: p, stocks: [], jobs: [job], stages: [stage], expenses: [], liabilities: [loan, loan], today: today, years: 1)
        precondition(borrowed.failure == date(2026, 2, 1))
        // Re-employment keeps access to investment funds.
        p.cashCents = 0; p.investmentCents = 300_00
        let temp = RunwayPlan(mode: .temporary, lossDate: today, returnDate: date(2026, 1, 2), salary: 0)
        let resumed = await RunwayEngine.calculate(plan: temp, profile: p, stocks: [], jobs: [job], stages: [stage], expenses: [record], liabilities: [], today: today, years: 1)
        precondition(resumed.failure == date(2026, 4, 10))
        let account = UserProfile()
        account.investmentCents = 100_000_00
        account.investmentRegistrationDate = date(2025, 1, 1)
        account.investmentAnnualReturnBasisPoints = 1000
        var simple = RunwayInvestment(profile: account, on: today)!
        precondition(RunwayEngine.cents(simple.value) == 110_000_00)
        _ = simple.redeem(5_000_00)
        precondition(RunwayEngine.cents(simple.capital) == 100_000_00)
        _ = simple.redeem(10_000_00)
        precondition(RunwayEngine.cents(simple.capital) == 95_000_00)
        account.investmentInterestMode = "复利"
        var compound = RunwayInvestment(profile: account, on: date(2025, 12, 31))!
        _ = compound.advance(to: today)
        precondition(abs(RunwayEngine.cents(compound.value) - 110_000_00) <= 1)
        precondition(compound.earnings == 0)
        // The calculation cap is never reported as exhaustion or a proof of sustainability.
        p.cashCents = 10_000_00; p.investmentCents = 0
        let capped = await RunwayEngine.calculate(plan: employed, profile: p, stocks: [], jobs: [job], stages: [stage], expenses: [record], liabilities: [], today: today, years: 1)
        precondition(capped.failure == nil && !capped.sustainable && capped.duration == "12 个月零 0 天")
        stage.salaryCents = 200_00
        let stable = await RunwayEngine.calculate(plan: employed, profile: p, stocks: [], jobs: [job], stages: [stage], expenses: [record], liabilities: [], today: today, years: 2)
        precondition(stable.sustainable && stable.failure == nil)
        // Independent persistence; data survives reopening.

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let schema = Schema([RunwaySettings.self])
        let config = ModelConfiguration(schema: schema, url: folder.appendingPathComponent("runway.store"), cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            try RunwayStore.save(loss, records: [], context: container.mainContext)
        }
        let reopened = try ModelContainer(for: schema, configurations: config)
        let rows = try reopened.mainContext.fetch(FetchDescriptor<RunwaySettings>())
        precondition(RunwayStore.active(rows) == loss)
        print("Runway tests passed: asset waterfall, exact deficit date, pre-loss deficit, compensation, payday, missing data, interest and persistence")
    }
}
