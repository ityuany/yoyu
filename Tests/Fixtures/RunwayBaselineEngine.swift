// Frozen pre-optimization engine for result parity and paired benchmarks.
// Test target only; never compiled into the app.
import Foundation

@MainActor enum RunwayBaselineEngine {
    static let calendar = ProfileRules.calendar
    static func day(_ date: Date) -> Date { calendar.startOfDay(for: date) }
    static func cents(_ value: Decimal) -> Int64 {
        var v = value, rounded = Decimal.zero
        NSDecimalRound(&rounded, &v, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }
    static func validation(_ plan: RunwayPlan, today: Date) -> String? {
        if plan.mode != .employed {
            guard let loss = plan.lossDate else { return "请填写失业时间。" }
            if day(loss) < day(today) { return "失业时间不能早于今天，请更新情景。" }
            if !(0...ProfileRules.maximumMoneyCents).contains(plan.flexible) || !(1...31).contains(plan.flexibleDay) { return "请完善灵活收入及到账日。" }
            if plan.mode == .temporary {
                guard let back = plan.returnDate, day(back) > day(loss) else { return "就业时间必须晚于失业时间。" }
                guard let salary = plan.salary, (0...ProfileRules.maximumMoneyCents).contains(salary), (1...31).contains(plan.payday) else { return "请填写就业薪资及发薪日。" }
            }
        }
        return nil
    }
    static func compensation(plan: RunwayPlan, jobs: [Employment], stages: [SalaryStage], today: Date) -> Int64? {
        guard plan.mode != .employed else { return 0 }
        guard let date = plan.lossDate, let job = CareerRules.current(jobs, on: today),
              job.severanceData != nil, let settings = SeveranceRules.settings(for: job)?.automatic else { return nil }
        return SeveranceRules.estimate(settings: settings, job: job,
            salaryCents: SeveranceRules.averageSalary(stages: stages, job: job, on: date),
            noticeSalaryCents: SeveranceRules.previousMonthSalary(stages: stages, job: job, on: date), on: date)?.amountCents
    }

    static func calculate(plan: RunwayPlan, profile: UserProfile?, stocks: [StockHolding], jobs: [Employment], stages: [SalaryStage], expenses: [RecurringExpense], liabilities: [LiabilityAccount], today: Date, years: Int = 100) async -> RunwayResult {
        let today = day(today)
        let origin = plan.mode == .employed ? today : day(plan.lossDate ?? today)
        let limit = calendar.date(byAdding: .year, value: years, to: max(today, origin))!
        var result = RunwayResult(origin: origin, end: today)
        func invalid(_ message: String) -> RunwayResult { var r = result; r.issue = message; return r }
        if let error = validation(plan, today: today) { return invalid(error) }
        guard let profile, let initialCash = profile.cashCents, initialCash >= 0 else { return invalid("请在财富中登记现金余额，没有现金可填写 0。") }
        guard let stock = StockRules.portfolio(stocks, profile: profile, on: today) ?? (stocks.isEmpty && profile.stockCents == nil && profile.stockSharesHundredths == nil && profile.stockPriceCents == nil ? 0 : nil) else { return invalid("请完善财富中的股票数量与估值。") }
        if profile.investmentCents != nil && profile.investmentCents != 0 && (profile.investmentRegistrationDate == nil || profile.investmentAnnualReturnBasisPoints == nil) { return invalid("请补全理财登记日期与收益率。") }
        var investment = RunwayInvestment(profile: profile, on: today)
        if profile.investmentCents != nil && investment == nil { return invalid("理财配置无法计算，请检查财富资料。") }
        let records = ExpenseRules.records(expenses)
        let plans = records.compactMap(\.plan)
        guard plans.count == records.count, plans.allSatisfy({ ExpenseRules.error($0) == nil }) else { return invalid("部分预计支出资料不完整。") }
        guard !plans.isEmpty || !liabilities.isEmpty else { return invalid("请先在财富中登记预计支出或还款安排。") }
        if ExpectedExpenseRules.missingBills(liabilities) { return invalid("请补全信用卡账单，或确认仅计算固定分期。") }
        let accounts = LiabilityRules.accounts(liabilities)
        for account in accounts {
            guard let snapshot = account.snapshot, let kind = account.kind, LiabilityRules.error(snapshot, kind: kind) == nil else { return invalid("请完善负债还款安排。") }
        }
        let job = CareerRules.current(jobs, on: today)
        if plan.mode == .employed || origin > today {
            guard let job, CareerRules.salary(stages, for: job, on: today)?.salaryCents != nil else { return invalid("请在职业履历中补全当前任职及薪资。") }
        }
        guard let compensation = compensation(plan: plan, jobs: jobs, stages: stages, today: today) else { return invalid("请在财富的裁员补偿中保存预测方案，并补全计算所需薪资记录。") }
        result.compensation = compensation
        let breaks: [ExpenseWorkBreak] = plan.mode == .employed ? [] : [.init(start: origin, end: plan.mode == .temporary ? plan.returnDate.map { calendar.date(byAdding: .day, value: -1, to: day($0))! } : nil)]
        var cash = Decimal(initialCash), equity = Decimal(stock)
        var date = today
        var month = Date.distantPast
        var payments: [Date: Int64] = [:]
        var previousExpense: Int64 = 0
        var income: Int64 = 0, gain: Decimal = 0, cost: Int64 = 0, debt: Int64 = 0, redeemed: Decimal = 0
        func point(_ date: Date) -> RunwayPoint {
            RunwayPoint(date: date, cash: cents(cash), stock: cents(equity), investment: cents(investment?.value ?? 0), income: income, gain: cents(gain), expense: cost, repayment: debt, redeemed: cents(redeemed))
        }
        // A conservative certificate: two years of cash buffer + guaranteed annual
        // salary/flexible income cover an upper bound of every expense, with no debts.
        let annualUpper = plans.reduce(Decimal.zero) { $0 + Decimal($1.amount) * Decimal(12 / $1.frequency.rawValue) }
        while date < limit {
            if Task.isCancelled { return invalid("计算已取消") }
            let currentMonth = ExpenseRules.month(date)
            if currentMonth != month {
                if month != .distantPast && date > origin { result.points.append(point(calendar.date(byAdding: .day, value: -1, to: date)!)) }
                await Task.yield()
                if Task.isCancelled { return invalid("计算已取消") }
                month = currentMonth
                income = 0; gain = 0; cost = 0; debt = 0; redeemed = 0; previousExpense = 0
                payments = [:]
                for account in accounts {
                    for payment in LiabilityRules.payments(account.snapshot!, kind: account.kind!, on: month) where ExpenseRules.month(payment.date) == month {
                        let key = day(payment.date)
                        guard let sum = LiabilityRules.sum([payments[key] ?? 0, payment.total]) else { return invalid("还款金额超过支持范围。") }
                        payments[key] = sum
                    }
                }
            }
            if date > today { gain += investment?.advance(to: date) ?? 0 }
            if date == origin {
                income = 0; gain = 0; cost = 0; debt = 0; redeemed = 0
                cash += Decimal(compensation)
                result.opening = point(date)
                result.points.append(point(date))
            }
            let returned = plan.mode == .temporary && date >= day(plan.returnDate!)
            let working = plan.mode == .employed || date < origin || returned
            let payDay = returned ? plan.payday : job?.salaryPaymentDay ?? 10
            if working && CareerRules.salaryPaymentDate(day: payDay, inMonth: date) == date {
                guard let salary = returned ? plan.salary : job.flatMap({ CareerRules.salary(stages, for: $0, on: date)?.salaryCents }), salary >= 0 else { return invalid("预测期间存在缺失的薪资记录。") }
                cash += Decimal(salary); income += salary
            } else if !working && CareerRules.salaryPaymentDate(day: plan.flexibleDay, inMonth: date) == date {
                cash += Decimal(plan.flexible); income += plan.flexible
            }
            // Cumulative monthly differences preserve rounding and the exact monthly sum.
            let partials = plans.map { ExpenseRules.amount($0, in: month, workBreaks: breaks, from: max(today, month), through: date) }
            guard partials.allSatisfy({ $0 != nil }), let cumulative = LiabilityRules.sum(partials.compactMap { $0 }) else { return invalid("预计支出无法计算。") }
            let daily = cumulative - previousExpense
            previousExpense = cumulative
            let repayment = payments[date] ?? 0
            cost += daily; debt += repayment
            let needed = Decimal(daily) + Decimal(repayment)
            if cash < needed { let used = min(equity, needed - cash); equity -= used; cash += used }
            if cash < needed { let used = investment?.redeem(needed - cash) ?? 0; cash += used; redeemed += used }
            if cash < needed {
                result.failure = date; result.end = date
                result.points.append(point(date))
                return result
            }
            cash -= needed
            result.end = date
            if cash + equity + (investment?.value ?? 0) > Decimal(ProfileRules.maximumMoneyCents) { return invalid("预测资产超过支持的金额范围，请调整资料。") }
            let stable = plan.mode != .temporary || returned
            let noFutureSalary = !working || returned || !CareerRules.stages(stages, for: job!).contains { ($0.effectiveDate ?? .distantFuture) > date }
            let guaranteed = working ? (returned ? plan.salary : job.flatMap { CareerRules.salary(stages, for: $0, on: date)?.salaryCents }) : plan.flexible
            if date >= origin && date >= calendar.date(byAdding: .year, value: 1, to: origin)! && stable && noFutureSalary && accounts.isEmpty,
               let guaranteed, Decimal(guaranteed) * 12 + max(0, (investment?.capital ?? 0) * (investment?.rate ?? 0)) >= annualUpper, cash >= annualUpper * 2 {
                result.sustainable = true
                result.points.append(point(date))
                return result
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        result.end = limit
        result.points.append(point(calendar.date(byAdding: .day, value: -1, to: limit)!))
        return result
    }
}
