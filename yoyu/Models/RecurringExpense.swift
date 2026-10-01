import Foundation
import SwiftData

nonisolated enum ExpenseFrequency: Int, Codable, CaseIterable, Identifiable {
    case monthly = 1, quarterly = 3, yearly = 12
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: Int { rawValue }
    /// 展示标题。
    var title: String { switch self { case .monthly: "每月"; case .quarterly: "每季度"; case .yearly: "每年" } }
    /// 展示单位。
    var unit: String { switch self { case .monthly: "月"; case .quarterly: "季度"; case .yearly: "年" } }
}

nonisolated struct ExpensePlan: Codable {
    /// 名称。
    var name = ""
    /// 支出金额，单位为分。
    var amount: Int64 = 0
    /// 该金额是否为估算值。
    var estimated = true
    /// 支出发生频率。
    var frequency: ExpenseFrequency = .monthly
    /// 开始日期。
    var start = Date()
    /// 结束日期，空值表示尚未结束。
    var end: Date?
    /// 是否按月内天数分摊发生金额。
    var spreadAcrossMonth = true
    /// 每月扣款或还款日，短月份按月末处理。
    var dueDay = 1
    /// 用户备注。
    var note = ""
    // An explicitly identified duplicate of a liability schedule. Optional for old records.
    /// 已覆盖该支出的负债业务标识，用于防止重复计算。
    var coveredByLiabilityID: String? = nil
    // Optional so plans saved before this setting remain decodable and continue normally.
    /// 工作中断期间是否暂停，空值按旧版照常发生处理。
    var pausesDuringWorkBreak: Bool? = nil
    /// 工作中断期间的支出行为说明。
    var workBreakBehavior: String { pausesDuringWorkBreak == true ? "工作中断期间暂停" : "工作中断期间照常" }
}

@Model final class RecurringExpense {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 旧版预计支出 JSON，仅用于兼容读取和迁移。
    var planData: Data?
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    /// 配置是否已保存为独立字段。
    var hasStructuredPlan: Bool = false
    /// 名称。
    var name: String = ""
    /// 支出金额，单位为分。
    var amount: Int64 = 0
    /// 该金额是否为估算值。
    var estimated: Bool = true
    /// 发生频率对应的月数，1 为每月、3 为每季度、12 为每年。
    var frequencyRaw: Int = 1
    /// 开始日期。
    var start: Date = Date()
    /// 结束日期，空值表示尚未结束。
    var end: Date?
    /// 是否按月内天数分摊发生金额。
    var spreadAcrossMonth: Bool = true
    /// 每月扣款或还款日，短月份按月末处理。
    var dueDay: Int = 1
    /// 用户备注。
    var note: String = ""
    /// 已覆盖该支出的负债业务标识，用于防止重复计算。
    var coveredByLiabilityID: String?
    /// 工作中断期间是否暂停，空值按旧版照常发生处理。
    var pausesDuringWorkBreak: Bool?
    init() {}
    /// 方案或配置。
    var plan: ExpensePlan? {
        if hasStructuredPlan {
            guard let frequency = ExpenseFrequency(rawValue: frequencyRaw) else { return nil }
            return ExpensePlan(name: name, amount: amount, estimated: estimated, frequency: frequency,
                start: start, end: end, spreadAcrossMonth: spreadAcrossMonth, dueDay: dueDay,
                note: note, coveredByLiabilityID: coveredByLiabilityID, pausesDuringWorkBreak: pausesDuringWorkBreak)
        }
        guard let planData else { return nil }
        return try? JSONDecoder().decode(ExpensePlan.self, from: planData)
    }
    func apply(_ plan: ExpensePlan) {
        name = plan.name; amount = plan.amount; estimated = plan.estimated
        frequencyRaw = plan.frequency.rawValue; start = plan.start; end = plan.end
        spreadAcrossMonth = plan.spreadAcrossMonth; dueDay = plan.dueDay; note = plan.note
        coveredByLiabilityID = plan.coveredByLiabilityID; pausesDuringWorkBreak = plan.pausesDuringWorkBreak
        hasStructuredPlan = true
    }
}

/// Scenario input only: inclusive first/last non-working days; nil end means ongoing.
/// Does not change the stored plan or infer employment from incomplete career records.
nonisolated struct ExpenseWorkBreak {
    /// 开始日期。
    var start: Date
    /// 结束日期，空值表示尚未结束。
    var end: Date?

    func contains(_ date: Date) -> Bool {
        let calendar = ProfileRules.calendar
        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: start)
            && (end.map { day <= calendar.startOfDay(for: $0) } ?? true)
    }
}

enum ExpenseRules {
    /// 业务日期计算采用的日历与时区。
    static var calendar: Calendar { ProfileRules.calendar }
    static func month(_ date: Date) -> Date { calendar.dateInterval(of: .month, for: date)!.start }
    static func dateLabel(_ date: Date) -> String { ProfileRules.dateKey(date).replacingOccurrences(of: "-", with: ".") }
    static func monthLabel(_ date: Date) -> String {
        let p = calendar.dateComponents([.year, .month], from: date)
        return "\(p.year!) 年 \(p.month!) 月"
    }
    static func error(_ plan: ExpensePlan) -> String? {
        if plan.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请填写开支用途。" }
        if !(1...ProfileRules.maximumMoneyCents).contains(plan.amount) { return "请填写大于零的金额，最多两位小数且不超过 1000 亿元。" }
        if let end = plan.end, calendar.startOfDay(for: end) < calendar.startOfDay(for: plan.start) { return "结束日期不能早于开始日期。" }
        if !(1...31).contains(plan.dueDay) { return "请选择 1 至 31 日。" }
        if plan.spreadAcrossMonth && plan.frequency != .monthly { return "月内陆续发生仅支持每月开支。" }
        return nil
    }
    /// Fixed payments are anchored to the start month; short months clamp the day,
    /// without shifting the requested day in subsequent months. End date is inclusive.
    static func amount(_ plan: ExpensePlan, in date: Date, workBreaks: [ExpenseWorkBreak] = [], from lowerBound: Date? = nil, through upperBound: Date? = nil) -> Int64? {
        guard error(plan) == nil else { return nil }
        let first = month(date)
        let next = calendar.date(byAdding: .month, value: 1, to: first)!
        let start = calendar.startOfDay(for: plan.start)
        let end = plan.end.map { calendar.startOfDay(for: $0) }
        guard next > start, end == nil || end! >= first else { return 0 }
        if plan.spreadAcrossMonth {
            let lower = max(first, start, lowerBound.map { calendar.startOfDay(for: $0) } ?? first)
            let upper = min(next, end.map { calendar.date(byAdding: .day, value: 1, to: $0)! } ?? next, upperBound.map { calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))! } ?? next)
            let span = calendar.dateComponents([.day], from: lower, to: upper).day!
            let days = (0..<max(0, span)).filter { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: lower)!
                return plan.pausesDuringWorkBreak != true || !workBreaks.contains { $0.contains(day) }
            }.count
            let totalDays = calendar.range(of: .day, in: .month, for: first)!.count
            var value = Decimal(plan.amount) * Decimal(days) / Decimal(totalDays)
            var rounded = Decimal()
            NSDecimalRound(&rounded, &value, 0, .plain)
            return NSDecimalNumber(decimal: rounded).int64Value
        }
        let offset = calendar.dateComponents([.month], from: month(start), to: first).month!
        guard offset >= 0, offset % plan.frequency.rawValue == 0 else { return 0 }
        let day = min(plan.dueDay, calendar.range(of: .day, in: .month, for: first)!.count)
        let due = calendar.date(byAdding: .day, value: day - 1, to: first)!
        let paused = plan.pausesDuringWorkBreak == true && workBreaks.contains { $0.contains(due) }
        let inWindow = (lowerBound.map { due >= calendar.startOfDay(for: $0) } ?? true)
            && (upperBound.map { due <= calendar.startOfDay(for: $0) } ?? true)
        return due >= start && (end == nil || due <= end!) && !paused && inWindow ? plan.amount : 0
    }
    /// Resolve old plans with separate start/day fields without changing their schedule.
    static func firstPaymentDate(_ plan: ExpensePlan) -> Date {
        let start = calendar.startOfDay(for: plan.start)
        func due(in month: Date) -> Date {
            let day = min(max(plan.dueDay, 1), calendar.range(of: .day, in: .month, for: month)!.count)
            return calendar.date(byAdding: .day, value: day - 1, to: month)!
        }
        let firstMonth = month(start)
        let candidate = due(in: firstMonth)
        if candidate >= start { return candidate }
        return due(in: calendar.date(byAdding: .month, value: plan.frequency.rawValue, to: firstMonth)!)
    }
    static func paymentPreview(_ plan: ExpensePlan) -> [Date] {
        guard !plan.spreadAcrossMonth else { return [] }
        let first = firstPaymentDate(plan)
        return (0..<3).compactMap { offset in
            let month = calendar.date(byAdding: .month, value: offset * plan.frequency.rawValue, to: month(first))!
            let day = min(max(plan.dueDay, 1), calendar.range(of: .day, in: .month, for: month)!.count)
            let date = calendar.date(byAdding: .day, value: day - 1, to: month)!
            if let end = plan.end, date > calendar.startOfDay(for: end) { return nil }
            return date
        }
    }
    static func records(_ records: [RecurringExpense]) -> [RecurringExpense] {
        Dictionary(grouping: records, by: \.id).values.compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted {
                let a = $0.plan?.name ?? "", b = $1.plan?.name ?? ""
                return a == b ? $0.id < $1.id : a.localizedStandardCompare(b) == .orderedAscending
            }
    }
    static func total(_ records: [RecurringExpense], in date: Date, workBreaks: [ExpenseWorkBreak] = []) -> Int64? {
        var total: Int64 = 0
        for record in self.records(records) {
            guard let plan = record.plan, let amount = amount(plan, in: date, workBreaks: workBreaks) else { return nil }
            let sum = total.addingReportingOverflow(amount)
            guard !sum.overflow, sum.partialValue <= ProfileRules.maximumMoneyCents else { return nil }
            total = sum.partialValue
        }
        return total
    }
    static func status(_ plan: ExpensePlan, on date: Date) -> String {
        let today = calendar.startOfDay(for: date)
        if today < calendar.startOfDay(for: plan.start) { return "未开始" }
        if let end = plan.end, today > calendar.startOfDay(for: end) { return "已结束" }
        return "进行中"
    }
    static func monthStatus(_ plan: ExpensePlan, in date: Date) -> String {
        let first = month(date)
        let next = calendar.date(byAdding: .month, value: 1, to: first)!
        if calendar.startOfDay(for: plan.start) >= next { return "未开始" }
        if let end = plan.end, calendar.startOfDay(for: end) < first { return "已结束" }
        return "当月有效"
    }
    static func scheduleLabel(_ plan: ExpensePlan) -> String {
        if plan.spreadAcrossMonth { return "月内陆续发生 · 按天折算" }
        let startMonth = calendar.component(.month, from: plan.start)
        switch plan.frequency {
        case .monthly: return "每月 \(plan.dueDay) 日"
        case .quarterly: return "从 \(startMonth) 月起每 3 个月 · \(plan.dueDay) 日"
        case .yearly: return "每年 \(startMonth) 月 \(plan.dueDay) 日"
        }
    }
    static func period(_ plan: ExpensePlan) -> String {
        "\(dateLabel(plan.start)) — \(plan.end.map { dateLabel($0) } ?? "长期")"
    }
}
