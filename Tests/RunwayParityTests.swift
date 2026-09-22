import Foundation

@main struct RunwayParityTests {
    @MainActor static func main() async throws {
        let c = ProfileRules.calendar
        var prefixChecks = 0
        for year in [2024, 2026] {
            for monthNumber in [1, 2, 4, 12] {
                let month = c.startOfDay(for: ProfileRules.date(year, monthNumber, 1))
                for seed in 0..<24 {
                    var plan = ExpensePlan()
                    plan.name = "边界支出"
                    plan.amount = [1, 2, 31, 100, 12_345_67, ProfileRules.maximumMoneyCents][seed % 6]
                    plan.start = c.date(byAdding: .day, value: seed % 8 - 3, to: month)!
                    plan.end = seed % 3 == 0 ? c.date(byAdding: .day, value: 17, to: month)! : nil
                    plan.spreadAcrossMonth = seed % 2 == 0
                    plan.dueDay = seed % 3 == 0 ? 31 : seed % 28 + 1
                    if !plan.spreadAcrossMonth { plan.frequency = [.monthly, .quarterly, .yearly][seed % 3] }
                    plan.pausesDuringWorkBreak = seed % 4 == 0
                    let lower = c.date(byAdding: .day, value: seed % 12, to: month)!
                    let breaks = [ExpenseWorkBreak(start: c.date(byAdding: .day, value: 8, to: month)!, end: c.date(byAdding: .day, value: 15, to: month)!)]
                    let prefixes = RunwayEngine.monthlyExpenses([plan], month: month, from: lower, breaks: breaks)
                    for (date, amount) in prefixes {
                        let old = ExpenseRules.amount(plan, in: month, workBreaks: breaks, from: lower, through: date)
                        precondition(amount == old, "Prefix mismatch \(date), seed \(seed): \(String(describing: amount)) != \(String(describing: old))")
                        prefixChecks += 1
                    }
                }
            }
        }
        for seed in 0..<36 {
            var f = try RunwayFixture("Parity \(seed)", years: 3, expenseCount: 3, loans: seed % 9 == 0)
            f.profile.cashCents = Int64(seed % 4) * 100_000_00
            f.profile.stockCents = Int64(seed % 3) * 50_000_00
            f.profile.investmentAnnualReturnBasisPoints = [-500, 0, 300, 1000][seed % 4]
            f.profile.investmentInterestMode = seed % 2 == 0 ? "单利" : "复利"
            f.profile.investmentRegistrationDate = ProfileRules.date(2024, 2, 29)
            for stage in f.stages { stage.salaryCents = Int64(seed % 4) * 7_000_00 }
            f.jobs[0].salaryPaymentDay = seed % 2 == 0 ? 31 : 10
            f.stages[0].effectiveDate = ProfileRules.date(2027, 1, 1)
            f.stages[0].salaryCents = 9_000_00
            let loss = c.date(byAdding: .day, value: seed % 5 * 30, to: f.today)!
            f.plan = RunwayPlan(mode: RunwayMode.allCases[seed % 3], lossDate: loss,
                returnDate: c.date(byAdding: .month, value: 6, to: loss), salary: 8_000_00, payday: 31,
                flexible: Int64(seed % 3) * 500_00, flexibleDay: 31)
            for (index, record) in f.expenses.enumerated() {
                var p = record.plan!
                p.amount += Int64(seed)
                p.spreadAcrossMonth = index == 0
                p.frequency = index == 1 ? .quarterly : .monthly
                p.dueDay = 31
                p.pausesDuringWorkBreak = index == 0 && seed % 2 == 0
                p.end = index == 2 ? ProfileRules.date(2027, 2, 28) : nil
                record.planData = try JSONEncoder().encode(p)
            }
            let old = await f.run(old: true), new = await f.run(old: false)
            precondition(signature(old) == signature(new), "Result mismatch \(seed)\nOLD \(signature(old))\nNEW \(signature(new))")
        }
        for automatic in [false, true] {
            for mode in [InstallmentRateMode.annual, .monthlyFee] {
                let f = try RunwayFixture("Credit parity", years: 3, loans: true)
                let card = f.liabilities[0]
                card.kindRaw = "creditCard"
                card.snapshotData = try JSONEncoder().encode(LiabilitySnapshot(balanceDate: f.today,
                    installments: [.init(name: "固定分期", principal: 100_000_00, months: 24,
                        nextDate: ProfileRules.date(2026, 7, 31), dueDay: 31,
                        terms: .init(rate: 1, mode: mode, paid: 1, automatic: automatic))], fixedInstallmentsOnly: true))
                let old = await f.run(old: true), new = await f.run(old: false)
                precondition(old.issue == nil, old.issue ?? "")
                precondition(signature(old) == signature(new), "Credit installment mismatch")
            }
        }
        print("Parity passed: \(prefixChecks) daily expense prefixes, 40 complete scenario ledgers including automatic/manual credit installments (every date and cent).")
    }
}
