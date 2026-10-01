import Foundation

struct DebtPayment: Identifiable {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    let id: String
    /// 原始子记录标识。
    let sourceID: UUID?
    /// 名称。
    let name: String
    /// 日期。
    let date: Date
    /// 本金，单位为分。
    let principal: Int64
    /// 利息金额，单位为分。
    let interest: Int64
    /// 剩余金额。
    let remaining: Int64?
    /// 合计值。
    var total: Int64 { principal + interest }
}
