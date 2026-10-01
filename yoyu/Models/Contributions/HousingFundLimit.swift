import Foundation
import SwiftData

@Model
final class HousingFundLimit {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 适用城市。
    var city: String = "南京市"
    /// 生效月份，以月初日期表示。
    var effectiveMonth: Date = Date()
    /// 缴纳基数下限，单位为分。
    var lowerCents: Int64 = 0
    /// 缴纳基数上限，单位为分。
    var upperCents: Int64 = 0
    /// 资料依据状态的原始枚举值。
    var evidenceRaw: String = LimitEvidence.unverified.rawValue
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()

    init() {}

}
