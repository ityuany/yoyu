import Foundation

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
