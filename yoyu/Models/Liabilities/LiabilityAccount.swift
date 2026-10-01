import Foundation
import SwiftData

@Model final class LiabilityAccount {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 名称。
    var name: String = ""
    /// 负债类别的原始枚举值。
    var kindRaw: String = "mortgage"
    /// 旧版负债资料 JSON，仅用于兼容读取和迁移。
    var snapshotData: Data?
    // Legacy persisted field retained for SwiftData / CloudKit compatibility; no longer read or written.
    /// 旧历史字段，仅为数据库及云端结构兼容保留，当前不读写。
    var historyData: Data?
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    /// 负债资料是否已保存为字段及关联模型。
    var hasStructuredSnapshot: Bool = false
    /// 预期房贷组成数量，防止云端关联未到齐时少算负债。
    var mortgageCount: Int = 0
    /// 预期信用卡分期数量，防止云端关联未到齐时少算负债。
    var installmentCount: Int = 0
    /// 负债余额登记日期。
    var balanceDate: Date = Date()
    /// 信用卡总欠款，包含分期本金及已入账费用，单位为分。
    var cardTotal: Int64 = 0
    /// 本期应还账单金额，单位为分，空值表示尚未确认。
    var billDue: Int64?
    /// 本期账单到期日期。
    var billDate: Date = Date()
    /// 用户备注。
    var note: String = ""
    /// 是否已确认仅计算固定分期，空值表示旧资料未确认。
    var fixedInstallmentsOnly: Bool?
    /// 信用卡每月还款日。
    var cardRepaymentDay: Int?
    /// 该负债账户的房贷组成部分；删除账户时级联删除。
    @Relationship(deleteRule: .cascade, inverse: \MortgagePartRecord.account)
    var mortgageRecords: [MortgagePartRecord]?
    /// 该记录拥有的分期明细；删除所属记录时级联删除。
    @Relationship(deleteRule: .cascade, inverse: \CardInstallmentRecord.account)
    var installmentRecords: [CardInstallmentRecord]?
    init() {}

}
