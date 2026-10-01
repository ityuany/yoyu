import Foundation

enum LimitEvidence: String, CaseIterable, Identifiable {
    case official, provisional, unverified

    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String { rawValue }
    /// 展示标题。
    var title: String {
        switch self {
        case .official: "正式"
        case .provisional: "暂行"
        case .unverified: "待核"
        }
    }
    /// 状态符号。
    var symbol: String {
        switch self {
        case .official: "✅"
        case .provisional: "🟡"
        case .unverified: "❓"
        }
    }
}
