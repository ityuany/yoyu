import Foundation

struct EquityInstallment: Codable, Identifiable {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id = UUID()
    /// 日期。
    var date: Date
    /// 股票数量，单位为百分之一股。
    var shares: Int64
    /// 该期归属是否已取消，取消后保留历史但不再计值。
    var cancelled = false
}

struct EquityGrant: Codable, Identifiable {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id = UUID()
    /// 名称。
    var name: String
    /// 日期。
    var date: Date
    /// 股票数量，单位为百分之一股。
    var shares: Int64
    /// 分期明细。
    var installments: [EquityInstallment] = []
}

struct EquityDisposal: Codable, Identifiable {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id = UUID()
    /// 日期。
    var date: Date
    /// 股票数量，单位为百分之一股。
    var shares: Int64
}
