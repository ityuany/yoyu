import Foundation

struct EquityInstallment: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var shares: Int64
    var cancelled = false
}
struct EquityGrant: Codable, Identifiable {
    var id = UUID()
    var name: String
    var date: Date
    var shares: Int64
    var installments: [EquityInstallment] = []
}
struct EquityDisposal: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var shares: Int64
}
enum EquityRules {
    static func error(_ grant: EquityGrant) -> String? {
        guard !grant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, grant.shares > 0,
              grant.shares <= ProfileRules.maximumMoneyCents else { return "请填写批次名称及有效授予总量。" }
        guard grant.installments.allSatisfy({ $0.shares > 0 && $0.date >= grant.date }) else { return "归属数量须大于 0，日期不能早于授予日。" }
        guard grant.installments.reduce(Decimal.zero, { $0 + Decimal($1.shares) }) <= Decimal(grant.shares) else { return "各期数量合计不能超过授予总量。" }
        return nil
    }
    static func vested(_ grant: EquityGrant, on date: Date) -> Int64 {
        guard error(grant) == nil else { return 0 }
        return grant.installments.filter { !$0.cancelled && ProfileRules.calendar.startOfDay(for: $0.date) <= ProfileRules.calendar.startOfDay(for: date) }.reduce(0) { $0 + $1.shares }
    }
    static func unallocated(_ grant: EquityGrant) -> Int64 {
        guard error(grant) == nil else { return 0 }
        return grant.shares - grant.installments.reduce(0) { $0 + $1.shares }
    }
    /// Quantities use hundredths of a share; round the first three periods down to whole shares.
    static func splitFour(first: Date, months: Int, total: Int64) -> [EquityInstallment] {
        guard total >= 400, total <= ProfileRules.maximumMoneyCents, total % 100 == 0 else { return [] }
        let portion = (total / 100 / 4) * 100
        var result = generate(first: first, count: 4, months: months, shares: portion)
        guard result.count == 4 else { return [] }
        result[3].shares = total - portion * 3
        return result
    }
    static func generate(first: Date, count: Int, months: Int, shares: Int64) -> [EquityInstallment] {
        guard (1...120).contains(count), shares > 0, [1,3,12].contains(months) else { return [] }
        return (0..<count).compactMap { index in
            ProfileRules.calendar.date(byAdding: .month, value: index * months, to: ProfileRules.calendar.startOfDay(for: first))
                .map { EquityInstallment(date: $0, shares: shares) }
        }
    }
}
