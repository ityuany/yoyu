import Foundation
import SwiftData

/// 与默认记录一同同步，避免用户删除内置记录后下次启动又被补回。
@Model
final class SocialInsuranceLimitSeedState {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = "nanjing-limits-v1"
    /// 默认资料导入时间。
    var importedAt: Date = Date()
    init() {}
}
