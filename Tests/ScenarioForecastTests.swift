import Foundation
import SwiftData

@main struct ScenarioForecastTests {
    @MainActor static func main() throws {
        let date = ProfileRules.date
        let now = date(2026, 10, 1)
        let origin = ScenarioForecast.origin(after: now)
        var scenario = ForecastScenario(origin: origin)
        scenario.currentIncome = 3100_00
        scenario.returnIncome = 6200_00
        scenario.openingFunds = 10000_00
        scenario.mode = .temporaryBreak
        scenario.breakStart = date(2026, 10, 11)
        scenario.returnDate = date(2026, 10, 21)
        precondition(ScenarioForecast.income(scenario, in: origin) == 3200_00) // 10 days old + 11 days new
        precondition(!scenario.workBreaks[0].contains(date(2026, 10, 21)))
        precondition(scenario.workBreaks[0].contains(date(2026, 10, 20)))
        let living = RecurringExpense()
        living.planData = try JSONEncoder().encode(ExpensePlan(name: "生活费", amount: 3100_00, start: origin))
        let commute = RecurringExpense()
        commute.planData = try JSONEncoder().encode(ExpensePlan(name: "通勤", amount: 310_00, start: origin, pausesDuringWorkBreak: true))
        let result = ScenarioForecast.months(scenario: scenario, expenses: [living, commute], liabilities: [], after: now, count: 12)
        precondition(result[0].expense.total == 3310_00 && result[0].income == 3200_00)
        precondition(result[0].balance == 9890_00 && result[0].breakExpense == 1000_00)
        precondition(result[1].income == 6200_00 && result[1].workStatus == "已再就业")
        scenario.mode = .indefiniteBreak
        scenario.breakStart = origin
        scenario.currentIncome = nil
        let noWork = ScenarioForecast.months(scenario: scenario, expenses: [living, commute], liabilities: [], after: now, count: 12)
        precondition(noWork[0].income == 0 && noWork[3].balance == -2400_00)
        precondition(noWork[0].breakExpense == noWork[0].expense.total)
        scenario.mode = .employed
        precondition(ScenarioForecast.months(scenario: scenario, expenses: [living], liabilities: [], after: now, count: 12)[0].balance == nil)
        scenario.currentIncome = 0
        precondition(ScenarioForecast.income(scenario, in: origin) == 0)
        precondition(ScenarioForecast.months(scenario: scenario, expenses: [living], liabilities: [], after: date(2026, 11, 1), count: 12)[0].balance == nil)
        scenario.mode = .temporaryBreak
        scenario.returnDate = scenario.breakStart
        precondition(ScenarioForecast.error(scenario) != nil)
        scenario.returnDate = date(2026, 12, 1)
        scenario.returnIncome = nil
        precondition(ScenarioForecast.income(scenario, in: date(2026, 11, 1)) == 0)
        precondition(ScenarioForecast.income(scenario, in: date(2026, 12, 1)) == nil)
        // Narrow date window preserves original quarterly recurrence.
        let rent = ExpensePlan(name: "季付", amount: 9000_00, frequency: .quarterly, start: date(2026, 1, 15), spreadAcrossMonth: false, dueDay: 15)
        precondition(ExpenseRules.amount(rent, in: date(2026, 4, 1), from: date(2026, 4, 16)) == 0)
        precondition(ExpenseRules.amount(rent, in: date(2026, 4, 1), from: date(2026, 4, 1), through: date(2026, 4, 15)) == 9000_00)
        // A future break retains salary before it, including the remaining current month.
        var future = ForecastScenario(origin: ScenarioForecast.origin(after: date(2026, 9, 22)))
        future.currentIncome = 3000_00
        future.openingFunds = 10000_00
        future.mode = .temporaryBreak
        future.breakStart = date(2026, 12, 1)
        future.returnDate = date(2027, 3, 1)
        future.returnIncome = 6000_00
        let partial = ScenarioForecast.months(scenario: future, expenses: [], liabilities: [], after: date(2026, 9, 22), count: 7)
        precondition(partial[0].income == 900_00)
        precondition(partial[1].income == 3000_00 && partial[2].income == 3000_00)
        precondition(partial[3].income == 0 && partial[6].income == 6000_00)
        precondition(partial[2].balance == 16900_00)
        let dailyCost = RecurringExpense()
        dailyCost.planData = try JSONEncoder().encode(ExpensePlan(name: "日常", amount: 3000_00, start: date(2026, 9, 1)))
        let alreadyPaid = RecurringExpense()
        alreadyPaid.planData = try JSONEncoder().encode(ExpensePlan(name: "已到期扣款", amount: 1000_00, start: date(2026, 9, 1), spreadAcrossMonth: false, dueDay: 10))
        let remaining = ScenarioForecast.months(scenario: future, expenses: [dailyCost, alreadyPaid], liabilities: [], after: date(2026, 9, 22), count: 2)
        precondition(remaining[0].expense.total == 900_00 && remaining[1].expense.total == 4000_00)
        let retained = ScenarioForecast.months(scenario: future, expenses: [], liabilities: [], after: date(2026, 9, 22), count: 2, investmentValue: { when in when >= ProfileRules.calendar.startOfDay(for: date(2026, 10, 1)) ? 4000_00 : 5000_00 })
        precondition(retained[0].investmentGain == -1000_00 && retained[0].income == 900_00 && retained[0].balance == 10900_00)
        future.redemptionDate = date(2026, 11, 15)
        let invested = ScenarioForecast.months(scenario: future, expenses: [], liabilities: [], after: date(2026, 9, 22), count: 7, investmentValue: { _ in 5000_00 })
        precondition(invested[1].redemption == 0 && invested[2].redemption == 5000_00 && invested[3].redemption == 0)
        precondition(invested[2].balance == 21900_00 && invested[3].investmentGain == 0)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([ForecastScenarioRecord.self])
        let config = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("scenario.store"), cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            try ForecastScenarioStore.save(scenario, records: [], context: container.mainContext)
            let records = try container.mainContext.fetch(FetchDescriptor<ForecastScenarioRecord>())
            var draft = scenario; draft.openingFunds = 1
            precondition(records[0].scenario?.openingFunds == 10000_00)
            draft.returnDate = draft.breakStart
            do { try ForecastScenarioStore.save(draft, records: records, context: container.mainContext); preconditionFailure("invalid saved") }
            catch { precondition(records[0].scenario?.openingFunds == 10000_00) }
        }
        let reopened = try ModelContainer(for: schema, configurations: [config])
        let records = try reopened.mainContext.fetch(FetchDescriptor<ForecastScenarioRecord>())
        precondition(records.count == 1 && records[0].scenario?.mode == .temporaryBreak)
        precondition(records[0].scenario?.openingFunds == 10000_00)
        print("ScenarioForecastTests passed: income boundaries, paused expenses, deficit, unknown data, rollover, validation and persistence")
    }
}
