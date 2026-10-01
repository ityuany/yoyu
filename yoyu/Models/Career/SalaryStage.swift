import Foundation
import SwiftData

@Model
final class SalaryStage {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 所属任职记录的业务标识。
    var employmentID: String = ""
    /// 薪资阶段生效日期，空值表示旧资料待核对。
    var effectiveDate: Date?
    /// 税前月薪，单位为分。
    var salaryCents: Int64?
    // 旧版薪资阶段曾混存缴纳资料；保留字段以兼容已同步数据，不参与缴纳记录展示或计算。
    /// 个人养老保险缴纳比例，单位为基点，100 基点等于 1%。
    var pensionBasisPoints: Int64?
    /// 养老保险缴纳基数，单位为分。
    var pensionBaseCents: Int64?
    /// 个人公积金缴纳比例，单位为基点，100 基点等于 1%。
    var housingBasisPoints: Int64?
    /// 公积金缴纳基数，单位为分。
    var housingBaseCents: Int64?
    // Read only by the one-time import into BonusPayment. Kept in the store schema
    // so an existing development database can be opened before that import runs.
    /// 旧年终奖金额，单位为分。
    var bonusCents: Int64?
    /// 旧年终奖发放月份。
    var bonusMonth: Int = 12
    /// 调整原因。
    var reason: String = ""
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    init() {}
}
