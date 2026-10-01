import Foundation

enum InvestmentInterestMode: String, CaseIterable, Identifiable {
    case simple = "单利"
    case compound = "复利"
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: Self { self }
}

struct InvestmentProjection {
    /// 本金金额，单位为分。
    let principalCents: Int64
    /// 合计金额，单位为分。
    let totalCents: Int64
    /// 累计收益金额，单位为分。
    var earningsCents: Int64 { totalCents - principalCents }

    /// 可选择的收益率预设。
    static let presets = [3, 6, 12, 36, 60, 96, 120]
    static func duration(_ months: Int) -> String {
        months % 12 == 0 ? "\(months / 12) 年" : "\(months) 个月"
    }

    /// 年末复投，剩余月份按年收益率的十二分之一折算；仅在输出时舍入到分。
    /// 负收益最多损失本金，不将无杠杆理财模拟为负债。
    static func calculate(principal: Int64?, rate: Int64?, months: Int, mode: InvestmentInterestMode) -> Self? {
        guard let principal, let rate,
              (0...ProfileRules.maximumMoneyCents).contains(principal),
              (-10_000...10_000).contains(rate), (0...1200).contains(months) else { return nil }
        let r = Decimal(rate) / 10_000
        var total = Decimal(principal)
        if mode == .simple {
            total *= max(0, 1 + r * Decimal(months) / 12)
        } else {
            for _ in 0..<(months / 12) {
                total *= 1 + r
                guard total <= Decimal(ProfileRules.maximumMoneyCents) else { return nil }
            }
            total *= 1 + r * Decimal(months % 12) / 12
        }
        guard !total.isNaN, total >= 0, total <= Decimal(ProfileRules.maximumMoneyCents) else { return nil }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &total, 0, .plain)
        return Self(principalCents: principal, totalCents: NSDecimalNumber(decimal: rounded).int64Value)
    }
}
