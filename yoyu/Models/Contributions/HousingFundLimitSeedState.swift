import Foundation
import SwiftData

/// 与默认记录同步，避免删除后再次导入。
@Model
final class HousingFundLimitSeedState {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = "nanjing-housing-limits-v1"
    /// 默认资料导入时间。
    var importedAt: Date = Date()
    init() {}
}
