import Foundation
import SwiftData

@Model
final class ContributionStage {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 所属任职记录的业务标识。
    var employmentID: String = ""
    /// 生效月份，以月初日期表示。
    var effectiveMonth: Date = Date()
    /// 养老保险缴纳基数，单位为分。
    var pensionBaseCents: Int64?
    /// 个人养老保险缴纳比例，单位为基点，100 基点等于 1%。
    var pensionBasisPoints: Int64?
    /// 公积金缴纳基数，单位为分。
    var housingBaseCents: Int64?
    /// 个人公积金缴纳比例，单位为基点，100 基点等于 1%。
    var housingBasisPoints: Int64?
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    init() {}
}
