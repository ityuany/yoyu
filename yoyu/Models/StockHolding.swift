import Foundation
import SwiftData

struct StockVesting: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var sharesHundredths: Int64
}

@Model final class StockHolding {
    var id: String = UUID().uuidString
    var name: String = ""
    var employmentID: String = ""
    var grantData: Data?
    var disposalData: Data?
    var currency: String = "CNY"
    var priceCents: Int64 = 0
    var priceIsConfigured: Bool = true
    var priceUpdatedAt: Date = Date()
    var yuanRate: Double = 1
    var baselineDate: Date = Date()
    var initialSharesHundredths: Int64 = 0
    // 同一份草稿整体保存，避免编辑取消时留下独立计划记录。
    var vestingData: Data?
    var modifiedAt: Date = Date()
    init() {}
    var grants: [EquityGrant]? {
        if let grantData { return try? JSONDecoder().decode([EquityGrant].self, from: grantData) }
        guard let old = vestings else { return nil }
        if old.isEmpty { return [] }
        let sum = old.reduce(Decimal.zero) { $0 + Decimal($1.sharesHundredths) }
        guard sum <= Decimal(ProfileRules.maximumMoneyCents) else { return nil }
        return [EquityGrant(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "原有归属计划", date: min(baselineDate, old.map(\.date).min()!), shares: NSDecimalNumber(decimal: sum).int64Value, installments: old.map { EquityInstallment(id: $0.id, date: $0.date, shares: $0.sharesHundredths) })]
    }
    var disposals: [EquityDisposal]? {
        guard let disposalData else { return [] }
        return try? JSONDecoder().decode([EquityDisposal].self, from: disposalData)
    }
    var vestings: [StockVesting]? {
        guard let vestingData else { return [] }
        return try? JSONDecoder().decode([StockVesting].self, from: vestingData)
    }
}

enum StockRules {
    struct Value {
        let vestedShares: Int64
        let unvestedShares: Int64
        let vested: Int64
        let unvested: Int64
        var total: Int64 { vested + unvested }
    }
    static func holdings(_ values: [StockHolding]) -> [StockHolding] {
        Dictionary(grouping: values, by: \.id).values.compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    struct Balance {
        let vestedShares: Int64
        let unvestedShares: Int64
    }
    static func balance(_ holding: StockHolding, on date: Date) -> Balance? {
        guard let grants = holding.grants, let disposals = holding.disposals,
              grants.allSatisfy({ EquityRules.error($0) == nil }) else { return nil }
        let today = ProfileRules.calendar.startOfDay(for: date)
        var vested = Decimal(holding.initialSharesHundredths)
        var pending = Decimal.zero
        for grant in grants {
            let v = EquityRules.vested(grant, on: today)
            let cancelled = grant.installments.filter(\.cancelled).reduce(Int64(0)) { $0 + $1.shares }
            vested += Decimal(v)
            pending += Decimal(grant.shares - v - cancelled)
        }
        for disposal in disposals where disposal.date <= today {
            guard disposal.shares > 0 else { return nil }
            vested -= Decimal(disposal.shares)
        }
        guard vested >= 0, pending >= 0, vested + pending <= Decimal(ProfileRules.maximumMoneyCents) else { return nil }
        let v = NSDecimalNumber(decimal: vested).int64Value
        let u = NSDecimalNumber(decimal: pending).int64Value
        return Balance(vestedShares: v, unvestedShares: u)
    }
    static func canSave(_ holding: StockHolding, on date: Date) -> Bool {
        guard balance(holding, on: date) != nil else { return false }
        guard holding.priceIsConfigured else { return true }
        guard let value = value(holding, on: date) else { return false }
        return yuan(value.total, holding: holding) != nil
    }
    static func value(_ holding: StockHolding, on date: Date) -> Value? {
        guard holding.priceIsConfigured, let balance = balance(holding, on: date) else { return nil }
        let v = balance.vestedShares
        let u = balance.unvestedShares
        guard let vv = ProfileRules.stockValue(sharesHundredths: v, priceCents: holding.priceCents),
              let uv = ProfileRules.stockValue(sharesHundredths: u, priceCents: holding.priceCents), vv <= ProfileRules.maximumMoneyCents - uv else { return nil }
        return Value(vestedShares: v, unvestedShares: u, vested: vv, unvested: uv)
    }
    static func value(initial: Int64, plans: [StockVesting], price: Int64, on date: Date) -> Value? {
        guard initial >= 0 else { return nil }
        let today = ProfileRules.calendar.startOfDay(for: date)
        var vested = Decimal(initial)
        var unvested = Decimal.zero
        for plan in plans {
            guard plan.sharesHundredths > 0 else { return nil }
            if ProfileRules.calendar.startOfDay(for: plan.date) <= today {
                vested += Decimal(plan.sharesHundredths)
            } else { unvested += Decimal(plan.sharesHundredths) }
        }
        guard vested + unvested <= Decimal(ProfileRules.maximumMoneyCents) else { return nil }
        let v = NSDecimalNumber(decimal: vested).int64Value
        let u = NSDecimalNumber(decimal: unvested).int64Value
        guard let vestedValue = ProfileRules.stockValue(sharesHundredths: v, priceCents: price),
              let unvestedValue = ProfileRules.stockValue(sharesHundredths: u, priceCents: price),
              vestedValue <= ProfileRules.maximumMoneyCents - unvestedValue else { return nil }
        return Value(vestedShares: v, unvestedShares: u, vested: vestedValue, unvested: unvestedValue)
    }
    static func yuan(_ amount: Int64, holding: StockHolding) -> Int64? {
        guard holding.yuanRate.isFinite, holding.yuanRate > 0 else { return nil }
        guard let rate = Decimal(string: String(holding.yuanRate), locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return rounded(Decimal(amount) * (holding.currency == "CNY" ? 1 : rate))
    }
    private static func rounded(_ amount: Decimal) -> Int64? {
        guard amount >= 0, amount <= Decimal(ProfileRules.maximumMoneyCents) else { return nil }
        var input = amount
        var output = Decimal.zero
        NSDecimalRound(&output, &input, 0, .plain)
        return NSDecimalNumber(decimal: output).int64Value
    }
    static func legacy(_ profile: UserProfile?) -> Int64? {
        guard let profile, !profile.stockMigrated else { return nil }
        return profile.stockValueCents
    }
    static func needsLegacyReview(_ holdings: [StockHolding], profile: UserProfile?) -> Bool {
        guard let profile, !profile.stockMigrated,
              profile.stockCents != nil || profile.stockSharesHundredths != nil || profile.stockPriceCents != nil else { return false }
        let migratedID = "legacy-stock-\(profile.createdAt.timeIntervalSince1970)"
        return !holdings.contains { $0.id == migratedID }
    }

    static func portfolio(_ holdings: [StockHolding], profile: UserProfile?, on date: Date, unvested: Bool = false) -> Int64? {
        let rows = self.holdings(holdings)
        // Until the owner reconciles old and company records, their overlap is unknown.
        if !rows.isEmpty && needsLegacyReview(rows, profile: profile) { return nil }
        let migratedID = profile.map { "legacy-stock-\($0.createdAt.timeIntervalSince1970)" }
        let previous = rows.contains(where: { $0.id == migratedID }) ? nil : legacy(profile)
        guard !rows.isEmpty || previous != nil else { return nil }
        var total = Decimal(unvested ? 0 : previous ?? 0)
        for row in rows {
            guard let value = value(row, on: date), let converted = yuan(unvested ? value.unvested : value.vested, holding: row) else { return nil }
            total += Decimal(converted)
        }
        return rounded(total)
    }
    static func wealth(_ holdings: [StockHolding], profile: UserProfile?, on date: Date, compensationCents: Int64? = nil) -> Int64? {
        if let compensationCents, !(0...ProfileRules.maximumMoneyCents).contains(compensationCents) { return nil }
        let stocks = portfolio(holdings, profile: profile, on: date)
        if !holdings.isEmpty && stocks == nil { return nil }
        let investment = profile?.investmentValue(on: date)
        if profile?.investmentCents != nil && investment == nil { return nil }
        let parts = [profile?.cashCents, stocks, investment, compensationCents].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return rounded(parts.reduce(Decimal.zero) { $0 + Decimal($1) })
    }
    static func money(_ cents: Int64?, currency: String) -> String {
        guard let cents else { return "待补全" }
        return (Decimal(cents) / 100).formatted(.currency(code: currency).locale(Locale(identifier: "zh_CN")).precision(.fractionLength(2)))
    }
}
