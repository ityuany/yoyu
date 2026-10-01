import Foundation
import SwiftData

@Model final class StockHolding {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 名称。
    var name: String = ""
    /// 所属任职记录的业务标识。
    var employmentID: String = ""
    /// 旧版股票授予 JSON，仅用于兼容读取和迁移。
    var grantData: Data?
    /// 旧版股票处置 JSON，仅用于兼容读取和迁移。
    var disposalData: Data?
    /// 股价使用的货币代码。
    var currency: String = "CNY"
    /// 股票单价，以该货币的百分之一单位表示。
    var priceCents: Int64 = 0
    /// 股票价格是否已经明确填写。
    var priceIsConfigured: Bool = true
    /// 股价最近更新时间。
    var priceUpdatedAt: Date = Date()
    /// 一单位股价货币兑换人民币的汇率。
    var yuanRate: Double = 1
    /// 初始持仓登记日期。
    var baselineDate: Date = Date()
    /// 初始已持有股票数量，单位为百分之一股。
    var initialSharesHundredths: Int64 = 0
    // 同一份草稿整体保存，避免编辑取消时留下独立计划记录。
    /// 旧版归属计划 JSON，仅用于兼容读取和迁移。
    var vestingData: Data?
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    /// 授予批次是否已保存为关联模型。
    var hasStructuredGrants: Bool = false
    /// 处置记录是否已保存为关联模型。
    var hasStructuredDisposals: Bool = false
    /// 预期授予批次数，云端关联尚未到齐时阻止显示不完整估值。
    var grantCount: Int = 0
    /// 预期处置记录数，云端关联尚未到齐时阻止显示不完整估值。
    var disposalCount: Int = 0
    /// 该持仓拥有的授予批次；删除持仓时级联删除。
    @Relationship(deleteRule: .cascade, inverse: \EquityGrantRecord.holding)
    var grantRecords: [EquityGrantRecord]?
    /// 该持仓拥有的处置记录；删除持仓时级联删除。
    @Relationship(deleteRule: .cascade, inverse: \EquityDisposalRecord.holding)
    var disposalRecords: [EquityDisposalRecord]?
    init() {}

}
