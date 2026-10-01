import Foundation

enum SeverancePlan: String, Codable, CaseIterable, Identifiable {
    case n, nPlusOne, twoN, customAmount

    // 旧自定义金额仅保留读取兼容，不再提供新建入口。
    static let selectable: [Self] = [.n, .nPlusOne, .twoN]

    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String { rawValue }
    /// 展示标题。
    var title: String {
        switch self {
        case .n: "N"
        case .nPlusOne: "N+1"
        case .twoN: "2N"
        case .customAmount: "自定义金额"
        }
    }
}

struct SeveranceSettings: Codable, Equatable {
    /// 方案或配置。
    var plan: SeverancePlan = .nPlusOne
    /// 补偿工资基数，单位为分。
    var baseSalaryCents: Int64?
    /// 代通知金工资基数，单位为分。
    var noticeSalaryCents: Int64?
    /// 工龄，单位为百分之一年。
    var tenureHundredths: Int64?
    /// 自定义补偿金额，单位为分。
    var customAmountCents: Int64?
    /// 地区三倍社平月工资标准，单位为分。
    var tripleAverageSalaryCents: Int64?

    // 保留所选预测方案；旧手动基数与年限仍统一从职业履历推算。
    /// 是否自动推进已还期数，空值保留旧版手动进度语义。
    var automatic: Self {
        var result = Self(plan: SeverancePlan.selectable.contains(plan) ? plan : .nPlusOne)
        result.tripleAverageSalaryCents = tripleAverageSalaryCents
        return result
    }
}
