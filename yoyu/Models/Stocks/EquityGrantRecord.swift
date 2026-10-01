import Foundation
import SwiftData

@Model final class EquityGrantRecord {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: UUID = UUID()
    /// 子记录最近修改时间，用于归并跨设备迁移产生的同源副本。
    var modifiedAt: Date = Date()
    /// 名称。
    var name: String = ""
    /// 日期。
    var date: Date = Date()
    /// 股票数量，单位为百分之一股。
    var shares: Int64 = 0
    /// 原始排列顺序，关联集合读取时据此还原顺序。
    var position: Int = 0
    /// 所属股票持仓，作为持仓关联的反向关系。
    var holding: StockHolding?
    /// 该记录拥有的分期明细；删除所属记录时级联删除。
    @Relationship(deleteRule: .cascade, inverse: \EquityInstallmentRecord.grant)
    var installmentRecords: [EquityInstallmentRecord]?
    /// 预期归属分期数量，防止云端只同步了部分明细时参与计算。
    var installmentCount: Int = 0
    init() {}

}
