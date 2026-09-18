import Foundation

/// 按上海自然日合并未来归属，不写入或改变授予记录。
enum VestingTimeline {
    struct Item: Identifiable {
        let holdingID: String
        let company: String
        let grantID: UUID
        let grantName: String
        let installmentID: UUID
        let shares: Int64
        let yuan: Int64?
        var id: String { "\(holdingID)-\(grantID)-\(installmentID)" }
    }
    struct Day: Identifiable {
        let date: Date
        let items: [Item]
        var id: Date { date }
        var year: Int { ProfileRules.calendar.component(.year, from: date) }
        var yuan: Int64? { VestingTimeline.sum(items.map(\.yuan)) }
        var batchCount: Int { Set(items.map { "\($0.holdingID)-\($0.grantID)" }).count }
        var companyCount: Int { Set(items.map(\.holdingID)).count }
    }
    struct Schedule {
        let days: [Day]
        let unallocated: [Item]
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
