import Foundation
import SwiftData

@Model final class MortgagePartRecord {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: UUID = UUID()
    /// 子记录最近修改时间，用于归并跨设备迁移产生的同源副本。
    var modifiedAt: Date = Date()
    /// 名称。
    var name: String = "商业贷款"
    /// 本金，单位为分。
    var principal: Int64 = 0
    /// 贷款年利率，以百分数表示。
    var annualPercent: Double = 0
    /// 还款期数，单位为月。
    var months: Int = 240
    /// 房贷还款方式的原始枚举值。
    var methodRaw: String = "annuity"
    /// 下一期还款日期。
    var nextDate: Date = Date()
    /// 每月扣款或还款日，短月份按月末处理。
    var dueDay: Int = 1
    /// 银行确认的每期本金，单位为分，空值表示按规则计算。
    var fixedPrincipal: Int64?
    /// 原始排列顺序，关联集合读取时据此还原顺序。
    var position: Int = 0
    /// 所属负债账户，作为账户关联的反向关系。
    var account: LiabilityAccount?
    init() {}

}
