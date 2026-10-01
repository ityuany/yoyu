import Foundation

enum LiabilityKind: String, Codable, CaseIterable, Identifiable {
    case mortgage, creditCard
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String { rawValue }
    /// 展示标题。
    var title: String { self == .mortgage ? "房贷" : "信用卡" }
    /// 界面图标名称。
    var icon: String { self == .mortgage ? "house" : "creditcard" }
}

enum MortgageMethod: String, Codable, CaseIterable, Identifiable {
    case annuity, equalPrincipal
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String { rawValue }
    /// 展示标题。
    var title: String { self == .annuity ? "等额本息" : "等额本金" }
}

enum InstallmentRateMode: String, Codable, CaseIterable, Identifiable {
    case annual, monthlyFee
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String { rawValue }
    /// 展示标题。
    var title: String { self == .annual ? "年利率" : "每期手续费率" }
}
