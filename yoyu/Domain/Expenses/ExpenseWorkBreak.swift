import Foundation

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
