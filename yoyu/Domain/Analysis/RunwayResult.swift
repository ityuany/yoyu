import Foundation

nonisolated struct RunwayPoint: Identifiable, Sendable {
    /// 日期。
    var date: Date
    /// 当前现金，单位为分。
    var cash: Int64
    /// 股票估值，单位为分。
    var stock: Int64
    /// 理财计算状态。
    var investment: Int64
    /// 收入金额，单位为分。
    var income: Int64 = 0
    /// 收益金额。
    var gain: Int64 = 0
    /// 支出金额，单位为分。
    var expense: Int64 = 0
    /// 还款金额，单位为分。
    var repayment: Int64 = 0
    /// 已赎回金额。
    var redeemed: Int64 = 0
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: Date { date }
    /// 合计值。
    var total: Int64 { cash + stock + investment }
}

nonisolated struct RunwayResult: Sendable {
    /// 预测起点日期。
    var origin: Date
    /// 结束日期，空值表示尚未结束。
    var end: Date
    /// 失败信息。
    var failure: Date?
    /// 无法计算的原因。
    var issue: String?
    /// 是否能维持至目标日期。
    var sustainable = false
    /// 期初金额。
    var opening: RunwayPoint?
    /// 预计补偿金额，单位为分。
    var compensation: Int64 = 0
    /// 图表数据点。
    var points: [RunwayPoint] = []
    /// 持续时长。
    var duration: String {
        let c = ProfileRules.calendar.dateComponents([.month, .day], from: origin, to: max(origin, failure ?? end))
        return "\(c.month ?? 0) 个月零 \(c.day ?? 0) 天"
    }
}
