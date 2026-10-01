import Foundation

nonisolated enum RunwayMode: String, Codable, CaseIterable, Identifiable {
    case employed, temporary, indefinite
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String { rawValue }
    /// 展示标题。
    var title: String {
        switch self { case .employed: "持续在职"; case .temporary: "阶段失业"; case .indefinite: "不再就业" }
    }
}

nonisolated struct RunwayPlan: Codable, Equatable {
    /// 预测就业模式的原始枚举值。
    var mode: RunwayMode = .employed
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
    /// 方案内容生成的计算缓存标识，不属于持久化字段。
    var cacheKey: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self).base64EncodedString()) ?? "invalid-plan"
    }
}
