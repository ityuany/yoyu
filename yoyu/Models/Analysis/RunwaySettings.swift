import Foundation
import SwiftData

@Model final class RunwaySettings {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 预测就业模式的原始枚举值。
    var mode: String = "employed"
    /// 旧版预测配置 JSON，仅用于兼容读取和迁移。
    var data: Data?
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    /// 配置是否已保存为独立字段。
    var hasStructuredPlan: Bool = false
    /// 工作中断开始日期。
    var lossDate: Date?
    /// 恢复就业日期。
    var returnDate: Date?
    /// 复工后税前月薪，单位为分。
    var salary: Int64?
    /// 复工后每月发薪日。
    var payday: Int = 10
    /// 每月灵活收入，单位为分。
    var flexible: Int64 = 0
    /// 每月灵活收入到账日。
    var flexibleDay: Int = 10
    init() {}

}
