import Foundation
import SwiftData

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

}
