import Foundation
import SwiftData

@Model final class EquityDisposalRecord {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: UUID = UUID()
    /// 子记录最近修改时间，用于归并跨设备迁移产生的同源副本。
    var modifiedAt: Date = Date()
    /// 日期。
    var date: Date = Date()
    /// 股票数量，单位为百分之一股。
    var shares: Int64 = 0
    /// 原始排列顺序，关联集合读取时据此还原顺序。
    var position: Int = 0
    /// 所属股票持仓，作为持仓关联的反向关系。
    var holding: StockHolding?
    init() {}

}
