import Foundation

struct StockVesting: Codable, Identifiable {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: UUID = UUID()
    /// 日期。
    var date: Date
    /// 股票数量，单位为百分之一股。
    var sharesHundredths: Int64
}
