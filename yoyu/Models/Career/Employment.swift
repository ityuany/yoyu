import Foundation
import SwiftData

@Model
final class Employment {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 名称。
    var name: String = ""
    /// 开始日期。
    var start: Date?
    /// 结束日期，空值表示尚未结束。
    var end: Date?
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    /// 是否遵循法定节假日及调休。
    var followsHolidays: Bool = true
    /// 每周工作日的位掩码。
    var workweekMask: Int = 62
    /// 上班时间距零点的分钟数。
    var startMinutes: Int = 540
    /// 下班时间距零点的分钟数。
    var endMinutes: Int = 1080
    /// 每月发薪日，范围为 1 至 31。
    var salaryPaymentDay: Int = 10
    /// 旧版补偿配置 JSON，仅用于兼容读取和迁移，新保存不再写入。
    var severanceData: Data?
    /// 补偿配置是否已保存为独立字段。
    var hasStructuredSeverance: Bool = false
    /// 补偿方案的原始枚举值。
    var severancePlanRaw: String = "nPlusOne"
    /// 旧手动补偿工资基数，单位为分。
    var severanceBaseSalaryCents: Int64?
    /// 旧手动代通知金工资基数，单位为分。
    var severanceNoticeSalaryCents: Int64?
    /// 旧手动工龄，单位为百分之一年。
    var severanceTenureHundredths: Int64?
    /// 旧自定义补偿金额，单位为分。
    var severanceCustomAmountCents: Int64?
    /// 地区三倍社平月工资标准，单位为分。
    var severanceTripleAverageSalaryCents: Int64?
    init() {}

}
