import Foundation

/// 按上海自然日合并未来归属，不写入或改变授予记录。
enum VestingTimeline {
    struct Item: Identifiable {
        /// 所属股票持仓的业务标识。
        let holdingID: String
        /// 所属企业名称。
        let company: String
        /// 所属授予批次标识。
        let grantID: UUID
        /// 授予批次名称。
        let grantName: String
        /// 归属分期标识。
        let installmentID: UUID
        /// 股票数量，单位为百分之一股。
        let shares: Int64
        /// 人民币参考金额，单位为分，空值表示无法估值。
        let yuan: Int64?
        /// 记录标识。
        var id: String { "\(holdingID)-\(grantID)-\(installmentID)" }
    }
    struct Day: Identifiable {
        /// 日期。
        let date: Date
        /// 同一天发生的归属明细。
        let items: [Item]
        /// 记录标识。
        var id: Date { date }
        /// 年份。
        var year: Int { ProfileRules.calendar.component(.year, from: date) }
        /// 人民币参考金额，单位为分，空值表示无法估值。
        var yuan: Int64? { VestingTimeline.sum(items.map(\.yuan)) }
        /// 涉及的授予批次数量。
        var batchCount: Int { Set(items.map { "\($0.holdingID)-\($0.grantID)" }).count }
        /// 涉及的企业数量。
        var companyCount: Int { Set(items.map(\.holdingID)).count }
    }
    struct Schedule {
        /// 天数。
        let days: [Day]
        /// 尚未安排归属日期的授予明细。
        let unallocated: [Item]
        /// 资料无法计算的企业数量。
        let invalidCompanies: Int
    }
    static func sum(_ values: [Int64?]) -> Int64? {
        guard values.allSatisfy({ $0 != nil }) else { return nil }
        let total = values.compactMap { $0 }.reduce(Decimal.zero) { $0 + Decimal($1) }
        guard total >= 0, total <= Decimal(ProfileRules.maximumMoneyCents) else { return nil }
        return NSDecimalNumber(decimal: total).int64Value
    }
    static func schedule(_ holdings: [StockHolding], on date: Date) -> Schedule {
        var grouped: [Date: [Item]] = [:]
        var unallocated: [Item] = []
        var invalid = 0
        let today = ProfileRules.calendar.startOfDay(for: date)
        for holding in StockRules.holdings(holdings) {
            guard let grants = holding.grants, grants.allSatisfy({ EquityRules.error($0) == nil }) else { invalid += 1; continue }
            func item(_ grant: EquityGrant, id: UUID, shares: Int64) -> Item {
                let value = holding.priceIsConfigured ? ProfileRules.stockValue(sharesHundredths: shares, priceCents: holding.priceCents).flatMap { StockRules.yuan($0, holding: holding) } : nil
                return Item(holdingID: holding.id, company: holding.name, grantID: grant.id, grantName: grant.name, installmentID: id, shares: shares, yuan: value)
            }
            for grant in grants {
                for installment in grant.installments where !installment.cancelled {
                    let day = ProfileRules.calendar.startOfDay(for: installment.date)
                    if day > today { grouped[day, default: []].append(item(grant, id: installment.id, shares: installment.shares)) }
                }
                let remaining = EquityRules.unallocated(grant)
                if remaining > 0 { unallocated.append(item(grant, id: grant.id, shares: remaining)) }
            }
        }
        return Schedule(days: grouped.keys.sorted().map { Day(date: $0, items: grouped[$0]!) }, unallocated: unallocated, invalidCompanies: invalid)
    }
}
