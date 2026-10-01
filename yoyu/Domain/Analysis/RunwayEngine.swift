import Foundation

/// 业务日期计算采用的日历与时区。
@MainActor enum RunwayEngine {
    nonisolated static var calendar: Calendar { ProfileRules.calendar }
    nonisolated static func day(_ date: Date) -> Date { calendar.startOfDay(for: date) }
    nonisolated static func cents(_ value: Decimal) -> Int64 {
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
    static func compensation(plan: RunwayPlan, jobs: [Employment], stages: [SalaryStage], bonuses: [BonusPayment] = [], today: Date) -> Int64? {
        guard plan.mode != .employed else { return 0 }
        guard let date = plan.lossDate, let job = CareerRules.current(jobs, on: today),
              (job.hasStructuredSeverance || job.severanceData != nil), let settings = SeveranceRules.settings(for: job)?.automatic else { return nil }
        return SeveranceRules.estimate(settings: settings, job: job,
            salaryCents: SeveranceRules.averageSalary(stages: stages, bonuses: bonuses, job: job, on: date),
            noticeSalaryCents: SeveranceRules.previousMonthSalary(stages: stages, job: job, on: date), on: date)?.amountCents
    }

    /// The old engine recalculated every prefix of every month. Build those same
    /// rounded prefixes in one pass, preserving per-plan rounding and pause dates.
    nonisolated static func monthlyExpenses(_ plans: [ExpensePlan], month: Date, from lower: Date, breaks: [ExpenseWorkBreak]) -> [Date: Int64?] {
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        let dates = (0..<count).map { calendar.date(byAdding: .day, value: $0, to: month)! }
        var prefixes = Array(repeating: [Int64](), count: count)
        for plan in plans {
            if plan.spreadAcrossMonth {
                let start = max(lower, day(plan.start)), end = plan.end.map(day) ?? .distantFuture
                var active = 0
                for (index, date) in dates.enumerated() {
                    if date >= start && date <= end && (plan.pausesDuringWorkBreak != true || !breaks.contains(where: { $0.contains(date) })) { active += 1 }
                    // Exact nonnegative rational rounding; splitting the quotient
                    // avoids overflow from multiplying a large amount by 31.
                    let divisor = Int64(count), days = Int64(active)
                    let amount = (plan.amount / divisor) * days + ((plan.amount % divisor) * days * 2 + divisor) / (2 * divisor)
                    prefixes[index].append(amount)
                }
            } else {
                let start = day(plan.start)
                let due = calendar.date(byAdding: .day, value: min(plan.dueDay, count) - 1, to: month)!
                let offset = calendar.dateComponents([.month], from: calendar.dateInterval(of: .month, for: start)!.start, to: month).month!
                let active = offset >= 0 && offset % plan.frequency.rawValue == 0 && due >= max(start, lower)
                    && (plan.end.map { due <= day($0) } ?? true)
                    && (plan.pausesDuringWorkBreak != true || !breaks.contains { $0.contains(due) })
                let amount = active ? plan.amount : 0
                let dueIndex = min(plan.dueDay, count) - 1
                for index in dates.indices { prefixes[index].append(index >= dueIndex ? amount : 0) }
            }
        }
        return Dictionary(uniqueKeysWithValues: dates.indices.map { (dates[$0], sum(prefixes[$0])) })
    }

    nonisolated private static func sum(_ values: [Int64]) -> Int64? {
        var result: Int64 = 0
        for value in values {
            let next = result.addingReportingOverflow(value)
            guard !next.overflow, next.partialValue <= ProfileRules.maximumMoneyCents else { return nil }
            result = next.partialValue
        }
        return result
    }
    nonisolated private static func payDate(day: Int, month: Date) -> Date? {
        guard (1...31).contains(day) else { return nil }
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        return calendar.date(byAdding: .day, value: min(day, count) - 1, to: month)
    }

    static func calculate(plan: RunwayPlan, profile: UserProfile?, stocks: [StockHolding], jobs: [Employment], stages: [SalaryStage], bonuses: [BonusPayment] = [], expenses: [RecurringExpense], liabilities: [LiabilityAccount], today: Date, years: Int? = nil) async -> RunwayResult {
        let today = day(today)
        let origin = plan.mode == .employed ? today : day(plan.lossDate ?? today)
        var result = RunwayResult(origin: origin, end: today)
        func invalid(_ message: String) -> RunwayResult { var r = result; r.issue = message; return r }
        if let error = validation(plan, today: today) { return invalid(error) }
        guard let retirement = profile.flatMap({ ProfileRules.retirementDate(year: $0.birthYear, month: $0.birthMonth, gender: $0.gender, femaleAge: $0.femaleRetirementAge) }) else {
            return invalid("请先在基本信息中完善出生年月、性别和退休类别，以计算退休时间。")
        }
        guard retirement > origin else { return invalid("退休时间已到或早于预测起点，无法计算生存时长。") }
        let limit = years.map { min(retirement, calendar.date(byAdding: .year, value: $0, to: max(today, origin))!) } ?? retirement
        guard let profile, let initialCash = profile.cashCents, initialCash >= 0 else { return invalid("请在财富中登记现金余额，没有现金可填写 0。") }
        guard let stock = StockRules.portfolio(stocks, profile: profile, on: today) ?? (stocks.isEmpty && profile.stockCents == nil && profile.stockSharesHundredths == nil && profile.stockPriceCents == nil ? 0 : nil) else { return invalid("请完善财富中的股票数量与估值。") }
        if profile.investmentCents != nil && profile.investmentCents != 0 && (profile.investmentRegistrationDate == nil || profile.investmentAnnualReturnBasisPoints == nil) { return invalid("请补全理财登记日期与收益率。") }
        let investment = RunwayInvestment(profile: profile, on: today)
        if profile.investmentCents != nil && investment == nil { return invalid("理财配置无法计算，请检查财富资料。") }
        let records = ExpenseRules.records(expenses)
        let plans = records.compactMap(\.plan)
        guard plans.count == records.count, plans.allSatisfy({ ExpenseRules.error($0) == nil }) else { return invalid("部分预计支出资料不完整。") }
        let payablePlans = ExpectedExpenseRules.uncoveredExpenses(records, liabilities: liabilities).compactMap(\.plan)
        guard !payablePlans.isEmpty || !liabilities.isEmpty else { return invalid("请先在财富中登记预计支出或还款安排。") }
        if ExpectedExpenseRules.missingBills(liabilities) { return invalid("请补全信用卡账单，或确认仅计算固定分期。") }
        let accounts = LiabilityRules.accounts(liabilities)
        for account in accounts {
            guard let snapshot = account.snapshot, let kind = account.kind, LiabilityRules.error(snapshot, kind: kind) == nil else { return invalid("请完善负债还款安排。") }
        }
        let job = CareerRules.current(jobs, on: today)
        if plan.mode == .employed || origin > today {
            guard let job, CareerRules.salary(stages, for: job, on: today)?.salaryCents != nil else { return invalid("请在职业履历中补全当前任职及薪资。") }
        }
        guard let compensation = compensation(plan: plan, jobs: jobs, stages: stages, bonuses: bonuses, today: today) else { return invalid("请在财富的裁员补偿中保存预测方案，并补全计算所需薪资记录。") }
        result.compensation = compensation
        let breaks: [ExpenseWorkBreak] = plan.mode == .employed ? [] : [.init(start: origin, end: plan.mode == .temporary ? plan.returnDate.map { calendar.date(byAdding: .day, value: -1, to: day($0))! } : nil)]
        // Materialize model-backed values once. Daily simulation never needs to
        // repeatedly decode debt plans or group and sort salary stages.
        let salaryRows = job.map { current in
            CareerRules.stages(stages, for: current).map { (date: $0.effectiveDate ?? .distantPast, salary: $0.salaryCents) }
        } ?? []
        let lastSalaryChange = job.map { current in
            CareerRules.stages(stages, for: current).map { $0.effectiveDate ?? .distantFuture }.max() ?? .distantPast
        } ?? .distantPast
        let jobEnd = job?.end ?? .distantFuture
        let originalPayday = job?.salaryPaymentDay ?? 10
        let returnDay = plan.returnDate.map(day)
        var paymentMonths: [Date: [Date: Int64]] = [:]
        var invalidPaymentMonths = Set<Date>()
        let firstMonth = ExpenseRules.month(today)
        for account in accounts {
            for payment in LiabilityRules.payments(account.snapshot!, kind: account.kind!, on: firstMonth) {
                let due = day(payment.date), month = ExpenseRules.month(payment.date)
                guard month >= firstMonth, due < limit else { continue }
                if let sum = LiabilityRules.sum([paymentMonths[month]?[due] ?? 0, payment.total]) {
                    paymentMonths[month, default: [:]][due] = sum
                } else { invalidPaymentMonths.insert(month) }
            }
        }
        return await simulate(plan: plan, today: today, origin: origin, limit: limit, initialResult: result,
            initialCash: initialCash, stock: stock, initialInvestment: investment, plans: payablePlans, breaks: breaks,
            salaryRows: salaryRows, lastSalaryChange: lastSalaryChange, jobEnd: jobEnd,
            originalPayday: originalPayday, returnDay: returnDay,
            paymentMonths: paymentMonths, invalidPaymentMonths: invalidPaymentMonths)
    }

    // Only Sendable value snapshots cross this boundary; SwiftData stays on MainActor.
    @concurrent nonisolated private static func simulate(
        plan: RunwayPlan, today: Date, origin: Date, limit: Date, initialResult: RunwayResult,
        initialCash: Int64, stock: Int64, initialInvestment: RunwayInvestment?, plans: [ExpensePlan], breaks: [ExpenseWorkBreak],
        salaryRows: [(date: Date, salary: Int64?)], lastSalaryChange: Date, jobEnd: Date,
        originalPayday: Int, returnDay: Date?,
        paymentMonths: [Date: [Date: Int64]], invalidPaymentMonths: Set<Date>
    ) async -> RunwayResult {
        var result = initialResult
        var investment = initialInvestment
        let compensation = result.compensation
        func invalid(_ message: String) -> RunwayResult { var r = result; r.issue = message; return r }
        func salary(on date: Date) -> Int64? { salaryRows.first { $0.date <= min(date, jobEnd) }?.salary }
        var cash = Decimal(initialCash), equity = Decimal(stock)
        var date = today
        var month = Date.distantPast
        var payments: [Date: Int64] = [:]
        var previousExpense: Int64 = 0
        var expenseAmounts: [Date: Int64?] = [:]
        var originalPayDate: Date?, returnPayDate: Date?, flexiblePayDate: Date?
        var income: Int64 = 0, gain: Decimal = 0, cost: Int64 = 0, debt: Int64 = 0, redeemed: Decimal = 0
        func point(_ date: Date) -> RunwayPoint {
            RunwayPoint(date: date, cash: cents(cash), stock: cents(equity), investment: cents(investment?.value ?? 0), income: income, gain: cents(gain), expense: cost, repayment: debt, redeemed: cents(redeemed))
        }
        while date < limit {
            if Task.isCancelled { return invalid("计算已取消") }
            let currentMonth = calendar.dateInterval(of: .month, for: date)!.start
            if currentMonth != month {
                if month != .distantPast && date > origin { result.points.append(point(calendar.date(byAdding: .day, value: -1, to: date)!)) }
                await Task.yield()
                if Task.isCancelled { return invalid("计算已取消") }
                month = currentMonth
                income = 0; gain = 0; cost = 0; debt = 0; redeemed = 0; previousExpense = 0
                guard !invalidPaymentMonths.contains(month) else { return invalid("还款金额超过支持范围。") }
                payments = paymentMonths[month] ?? [:]
                expenseAmounts = monthlyExpenses(plans, month: month, from: max(today, month), breaks: breaks)
                originalPayDate = payDate(day: originalPayday, month: month)
                returnPayDate = payDate(day: plan.payday, month: month)
                flexiblePayDate = payDate(day: plan.flexibleDay, month: month)
            }
            if date > today { gain += investment?.advance(to: date) ?? 0 }
            if date == origin {
                income = 0; gain = 0; cost = 0; debt = 0; redeemed = 0
                cash += Decimal(compensation)
                result.opening = point(date)
                result.points.append(point(date))
            }
            let returned = plan.mode == .temporary && date >= returnDay!
            let working = plan.mode == .employed || date < origin || returned
            if working && (returned ? returnPayDate : originalPayDate) == date {
                guard let salary = returned ? plan.salary : salary(on: date), salary >= 0 else { return invalid("预测期间存在缺失的薪资记录。") }
                cash += Decimal(salary); income += salary
            } else if !working && flexiblePayDate == date {
                cash += Decimal(plan.flexible); income += plan.flexible
            }
            // Cumulative monthly differences preserve rounding and the exact monthly sum.
            guard let stored = expenseAmounts[date], let cumulative = stored else { return invalid("预计支出无法计算。") }
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
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        result.end = limit
        result.points.append(point(calendar.date(byAdding: .day, value: -1, to: limit)!))
        return result
    }
}
