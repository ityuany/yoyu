import Foundation

enum ProfileSection: String, Identifiable {
    case basic = "基本信息"
    case employment = "企业信息"
    case work = "工作安排"
    case wealth = "当前财富"
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String { rawValue }
}
