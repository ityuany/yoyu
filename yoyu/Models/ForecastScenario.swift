import Foundation
import SwiftData

nonisolated enum ForecastWorkMode: String, Codable, CaseIterable, Identifiable {
    case employed, temporaryBreak, indefiniteBreak
    var id: String { rawValue }
    var title: String {
        switch self {
        case .employed: "持续在职"
        case .temporaryBreak: "阶段性失业 / gap"
        case .indefiniteBreak: "长期不再就业"
        }
    }
    var subtitle: String {
        switch self {
        case .employed: "沿用当前月到手收入"
        case .temporaryBreak: "中断工作一段时间，再以新的收入开始"
        case .indefiniteBreak: "从指定日期起，预测期内不再计入工资"
        }
    }
    var icon: String {
        switch self {
        case .employed: "briefcase"
        case .temporaryBreak: "pause.circle"
        case .indefiniteBreak: "leaf"
        }
    }
}

nonisolated struct ForecastScenario: Codable {
    var mode: ForecastWorkMode = .employed
    var breakStart: Date
    var returnDate: Date
    var currentIncome: Int64?
    var returnIncome: Int64?
    var openingFunds: Int64?
    // Funds belong to a specific forecast origin, never silently roll into a new month.
    var redemptionDate: Date?
    var fundsMonth: Date

    init(origin: Date) {
        breakStart = origin
        returnDate = ProfileRules.calendar.date(byAdding: .month, value: 3, to: origin)!
        fundsMonth = origin
    }
    var workBreaks: [ExpenseWorkBreak] {
        guard mode != .employed else { return [] }
        let end = mode == .temporaryBreak
            ? ProfileRules.calendar.date(byAdding: .day, value: -1, to: ProfileRules.calendar.startOfDay(for: returnDate)) : nil
        return [.init(start: breakStart, end: end)]
    }
}

@Model final class ForecastScenarioRecord {
    var id: String = "primary"
    var data: Data?
    var modifiedAt: Date = Date()
    init() {}
    var scenario: ForecastScenario? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(ForecastScenario.self, from: data)
    }
}

@MainActor enum ForecastScenarioStore {
    static func current(_ records: [ForecastScenarioRecord]) -> ForecastScenarioRecord? {
        records.max { a, b in
            if a.modifiedAt != b.modifiedAt { return a.modifiedAt < b.modifiedAt }
            return (a.data?.base64EncodedString() ?? "") < (b.data?.base64EncodedString() ?? "")
        }
    }
    static func save(_ scenario: ForecastScenario, records: [ForecastScenarioRecord], context: ModelContext) throws {
        if let error = ScenarioForecast.error(scenario) { throw ExpenseSaveError.invalid(error) }
        let data = try JSONEncoder().encode(scenario)
        let record = current(records) ?? ForecastScenarioRecord()
        if records.isEmpty { context.insert(record) }
        record.data = data
        record.modifiedAt = Date()
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

struct ScenarioForecastMonth: Identifiable {
    let expense: ExpenseForecastMonth
    let income: Int64?
    let balance: Int64?
    let workStatus: String
    let breakExpense: Int64?
    var investmentGain: Int64? = 0
    var redemption: Int64? = 0
    var calculationStart: Date? = nil
    var id: Date { expense.date }
    var date: Date { expense.date }
}

enum ScenarioForecast {
    static var calendar: Calendar { ProfileRules.calendar }
    static func origin(after date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
    static func error(_ scenario: ForecastScenario) -> String? {
        if scenario.mode == .temporaryBreak,
           calendar.startOfDay(for: scenario.returnDate) <= calendar.startOfDay(for: scenario.breakStart) {
            return "再就业日期需要晚于失业开始日期。"
        }
        for amount in [scenario.currentIncome, scenario.returnIncome, scenario.openingFunds].compactMap({ $0 }) {
            if !(0...ProfileRules.maximumMoneyCents).contains(amount) { return "金额需为非负数，且不超过 1000 亿元。" }
        }
        return nil
    }
    static func income(_ scenario: ForecastScenario, in month: Date, from lowerBound: Date? = nil) -> Int64? {
        guard error(scenario) == nil else { return nil }
        let first = ExpenseRules.month(month)
        let days = calendar.range(of: .day, in: .month, for: first)!.count
        var sum = Decimal.zero
        for offset in 0..<days {
            let day = calendar.date(byAdding: .day, value: offset, to: first)!
            if let lowerBound, day < calendar.startOfDay(for: lowerBound) { continue }
            let amount: Int64?
            if scenario.mode == .employed || day < calendar.startOfDay(for: scenario.breakStart) {
                amount = scenario.currentIncome
            } else if scenario.mode == .temporaryBreak && day >= calendar.startOfDay(for: scenario.returnDate) {
                amount = scenario.returnIncome
            } else { amount = 0 }
            guard let amount else { return nil }
            sum += Decimal(amount)
        }
        var value = sum / Decimal(days), rounded = Decimal.zero
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }
    static func status(_ scenario: ForecastScenario, in month: Date) -> String {
        guard scenario.mode != .employed else { return "在职" }
        let first = ExpenseRules.month(month)
        let next = calendar.date(byAdding: .month, value: 1, to: first)!
        let start = calendar.startOfDay(for: scenario.breakStart)
        let resume = calendar.startOfDay(for: scenario.returnDate)
        if next <= start { return "在职" }
        if scenario.mode == .temporaryBreak && first >= resume { return "已再就业" }
        if start > first || (scenario.mode == .temporaryBreak && resume < next) { return "工作状态切换" }
        return "工作中断"
    }
    static func months(scenario: ForecastScenario, expenses: [RecurringExpense], liabilities: [LiabilityAccount], after date: Date, count: Int, investmentValue: ((Date) -> Int64?)? = nil) -> [ScenarioForecastMonth] {
        let start = origin(after: date)
        let costs = (0..<max(0, count)).map { offset in
            let month = calendar.date(byAdding: .month, value: offset, to: ExpenseRules.month(start))!
            let daily = ExpenseRules.records(expenses).map { record in
                record.plan.flatMap { ExpenseRules.amount($0, in: month, workBreaks: scenario.workBreaks, from: start) }
            }
            let repayments = LiabilityRules.accounts(liabilities).map { ExpectedExpenseRules.repayment($0, in: month, from: start) }
            return ExpenseForecastMonth(date: month,
                daily: daily.contains(where: { $0 == nil }) ? nil : LiabilityRules.sum(daily.compactMap { $0 }),
                repayment: repayments.contains(where: { $0 == nil }) ? nil : LiabilityRules.sum(repayments.compactMap { $0 }))
        }
        var balance = calendar.isDate(scenario.fundsMonth, inSameDayAs: start) ? scenario.openingFunds : nil
        if error(scenario) != nil { balance = nil }
        return costs.map { cost in
            let salary = income(scenario, in: cost.date, from: start)
            let end = calendar.date(byAdding: .month, value: 1, to: cost.date)!
            let redemptionDate = scenario.redemptionDate.map { calendar.startOfDay(for: $0) }
            let pays = redemptionDate.map { $0 >= max(start, cost.date) && $0 < end } ?? false
            let redemption: Int64? = pays ? investmentValue?(redemptionDate!) : 0
            let income = salary.flatMap { salary in redemption.map { salary + $0 } }
            let gainStart = max(start, cost.date)
            let gainEnd = min(end, redemptionDate ?? end)
            let gain: Int64? = gainEnd <= gainStart || investmentValue == nil ? 0 : investmentValue?(gainEnd).flatMap { final in investmentValue?(gainStart).map { final - $0 } }
            if let previous = balance, let income, let outflow = cost.total {
                let added = previous.addingReportingOverflow(income)
                let subtracted = added.partialValue.subtractingReportingOverflow(outflow)
                balance = added.overflow || subtracted.overflow ? nil : subtracted.partialValue
            } else { balance = nil }
            let gapCost: Int64?
            if let interval = scenario.workBreaks.first {
                let daily = ExpenseRules.records(expenses).map { record -> Int64? in
                    guard let plan = record.plan else { return nil }
                    return ExpenseRules.amount(plan, in: cost.date, workBreaks: scenario.workBreaks, from: max(start, interval.start), through: interval.end)
                }
                let repayments = LiabilityRules.accounts(liabilities).map {
                    ExpectedExpenseRules.repayment($0, in: cost.date, from: max(start, interval.start), through: interval.end)
                }
                let all = daily + repayments
                gapCost = all.contains(where: { $0 == nil }) ? nil : LiabilityRules.sum(all.compactMap { $0 })
            } else { gapCost = 0 }
            return ScenarioForecastMonth(expense: cost, income: income, balance: balance,
                                         workStatus: status(scenario, in: cost.date), breakExpense: gapCost, investmentGain: gain, redemption: redemption, calculationStart: max(start, cost.date))
        }
    }
}
