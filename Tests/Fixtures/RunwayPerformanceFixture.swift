import Foundation

@MainActor struct RunwayFixture {
    let name: String
    var plan: RunwayPlan
    let profile: UserProfile
    let jobs: [Employment]
    let stages: [SalaryStage]
    let expenses: [RecurringExpense]
    let liabilities: [LiabilityAccount]
    let today = ProfileRules.date(2026, 9, 22)
    let years: Int

    init(_ name: String, years: Int, expenseCount: Int = 1, loans: Bool = false, example: Bool = false) throws {
        self.name = name; self.years = years
        let p = UserProfile()
        p.birthYear = 1990
        p.birthMonth = 1
        p.gender = "男"
        p.cashCents = example ? 80_000_00 : 50_000_000_00
        p.stockCents = 120_000_00; p.investmentCents = 200_000_00
        p.investmentRegistrationDate = ProfileRules.date(2026, 9, 22)
        p.investmentAnnualReturnBasisPoints = 300
        profile = p
        let job = Employment(); job.start = ProfileRules.date(2020, 1, 1)
        job.severanceData = try JSONEncoder().encode(SeveranceSettings())
        jobs = [job]
        stages = (0..<12).map { index in
            let s = SalaryStage(); s.employmentID = job.id
            s.effectiveDate = ProfileRules.date(2020, index + 1, 1); s.salaryCents = example ? 20_000_00 : 0
            return s
        }
        expenses = try (0..<expenseCount).map { index in
            var plan = ExpensePlan(); plan.name = "开支\(index)"; plan.amount = 12_000_00 / Int64(expenseCount)
            plan.start = ProfileRules.date(2026, 1, 1)
            let r = RecurringExpense(); r.planData = try JSONEncoder().encode(plan); return r
        }
        if loans {
            liabilities = try (0..<2).map { index in
                let r = LiabilityAccount()
                r.snapshotData = try JSONEncoder().encode(LiabilitySnapshot(balanceDate: ProfileRules.date(2026, 9, 22), mortgages: [.init(principal: 1_000_000_00, annualPercent: 3, months: 360, nextDate: ProfileRules.date(2026, 10, 10 + index), dueDay: 10 + index)]))
                return r
            }
        } else { liabilities = [] }
        plan = example ? RunwayPlan(mode: .indefinite, lossDate: ProfileRules.date(2026, 10, 1), flexible: 2_000_00, flexibleDay: 15) : RunwayPlan()
    }
    func run(old: Bool) async -> RunwayResult {
        if old { return await RunwayBaselineEngine.calculate(plan: plan, profile: profile, stocks: [], jobs: jobs, stages: stages, expenses: expenses, liabilities: liabilities, today: today, years: years) }
        return await RunwayEngine.calculate(plan: plan, profile: profile, stocks: [], jobs: jobs, stages: stages, expenses: expenses, liabilities: liabilities, today: today, years: years)
    }
}

func signature(_ r: RunwayResult) -> String {
    func point(_ p: RunwayPoint) -> String {
        "\(p.date.timeIntervalSinceReferenceDate):\([p.cash,p.stock,p.investment,p.income,p.gain,p.expense,p.repayment,p.redeemed])"
    }
    return "\(r.origin)|\(r.end)|\(String(describing:r.failure))|\(String(describing:r.issue))|\(r.sustainable)|\(r.compensation)|\(r.duration)|\(r.opening.map(point) ?? "nil")|" + r.points.map(point).joined(separator: "|")
}

