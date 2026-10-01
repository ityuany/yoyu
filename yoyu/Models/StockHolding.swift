import Foundation
import SwiftData

struct StockVesting: Codable, Identifiable {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: UUID = UUID()
    /// 日期。
    var date: Date
    /// 股票数量，单位为百分之一股。
    var sharesHundredths: Int64
}

@Model final class StockHolding {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 名称。
    var name: String = ""
    /// 所属任职记录的业务标识。
    var employmentID: String = ""
    /// 旧版股票授予 JSON，仅用于兼容读取和迁移。
    var grantData: Data?
    /// 旧版股票处置 JSON，仅用于兼容读取和迁移。
    var disposalData: Data?
    /// 股价使用的货币代码。
    var currency: String = "CNY"
    /// 股票单价，以该货币的百分之一单位表示。
    var priceCents: Int64 = 0
    /// 股票价格是否已经明确填写。
    var priceIsConfigured: Bool = true
    /// 股价最近更新时间。
    var priceUpdatedAt: Date = Date()
    /// 一单位股价货币兑换人民币的汇率。
    var yuanRate: Double = 1
    /// 初始持仓登记日期。
    var baselineDate: Date = Date()
    /// 初始已持有股票数量，单位为百分之一股。
    var initialSharesHundredths: Int64 = 0
    // 同一份草稿整体保存，避免编辑取消时留下独立计划记录。
    /// 旧版归属计划 JSON，仅用于兼容读取和迁移。
    var vestingData: Data?
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    /// 授予批次是否已保存为关联模型。
    var hasStructuredGrants: Bool = false
    /// 处置记录是否已保存为关联模型。
    var hasStructuredDisposals: Bool = false
    /// 预期授予批次数，云端关联尚未到齐时阻止显示不完整估值。
    var grantCount: Int = 0
    /// 预期处置记录数，云端关联尚未到齐时阻止显示不完整估值。
    var disposalCount: Int = 0
    /// 该持仓拥有的授予批次；删除持仓时级联删除。
    @Relationship(deleteRule: .cascade, inverse: \EquityGrantRecord.holding)
    var grantRecords: [EquityGrantRecord]?
    /// 该持仓拥有的处置记录；删除持仓时级联删除。
    @Relationship(deleteRule: .cascade, inverse: \EquityDisposalRecord.holding)
    var disposalRecords: [EquityDisposalRecord]?
    init() {}
    /// 股票授予批次的值类型快照。
    var grants: [EquityGrant]? {
        if hasStructuredGrants {
            let records = Dictionary(grouping: (grantRecords ?? []), by: \.id).values.compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            guard records.count == grantCount else { return nil }
            let values = records.sorted { $0.position < $1.position }.compactMap(\.value)
            return values.count == records.count ? values : nil
        }
        if let grantData { return try? JSONDecoder().decode([EquityGrant].self, from: grantData) }
        guard let old = vestings else { return nil }
        if old.isEmpty { return [] }
        let sum = old.reduce(Decimal.zero) { $0 + Decimal($1.sharesHundredths) }
        guard sum <= Decimal(ProfileRules.maximumMoneyCents) else { return nil }
        return [EquityGrant(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "原有归属计划", date: min(baselineDate, old.map(\.date).min()!), shares: NSDecimalNumber(decimal: sum).int64Value, installments: old.map { EquityInstallment(id: $0.id, date: $0.date, shares: $0.sharesHundredths) })]
    }
    /// 股票处置记录的值类型快照。
    var disposals: [EquityDisposal]? {
        if hasStructuredDisposals {
            let records = Dictionary(grouping: (disposalRecords ?? []), by: \.id).values.compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            guard records.count == disposalCount else { return nil }
            return records.sorted { $0.position < $1.position }.map(\.value)
        }
        guard let disposalData else { return [] }
        return try? JSONDecoder().decode([EquityDisposal].self, from: disposalData)
    }
    /// 旧归属计划的值类型快照。
    var vestings: [StockVesting]? {
        if hasStructuredGrants {
            guard let grants else { return nil }
            return grants.flatMap(\.installments).filter { !$0.cancelled }
                .map { StockVesting(id: $0.id, date: $0.date, sharesHundredths: $0.shares) }
        }
        guard let vestingData else { return [] }
        return try? JSONDecoder().decode([StockVesting].self, from: vestingData)
    }
}


extension StockHolding {
    func applyGrants(_ values: [EquityGrant], at date: Date = Date()) {
        let old = grantRecords ?? []
        var records: [EquityGrantRecord] = []
        for (position, value) in values.enumerated() {
            let record = old.filter { $0.id == value.id }.max { $0.modifiedAt < $1.modifiedAt } ?? EquityGrantRecord()
            record.modifiedAt = date
            record.id = value.id; record.name = value.name; record.date = value.date
            record.shares = value.shares; record.position = position
            record.applyInstallments(value.installments, at: date)
            records.append(record)
        }
        grantRecords = records
        for record in old where !records.contains(where: { $0 === record }) { modelContext?.delete(record) }
        grantCount = values.count
        hasStructuredGrants = true
    }
    func applyDisposals(_ values: [EquityDisposal], at date: Date = Date()) {
        let old = disposalRecords ?? []
        let records = values.enumerated().map { position, value in
            let record = old.filter { $0.id == value.id }.max { $0.modifiedAt < $1.modifiedAt } ?? EquityDisposalRecord()
            record.modifiedAt = date
            record.id = value.id; record.date = value.date; record.shares = value.shares; record.position = position
            return record
        }
        disposalRecords = records
        for record in old where !records.contains(where: { $0 === record }) { modelContext?.delete(record) }
        disposalCount = values.count
        hasStructuredDisposals = true
    }
    /// 将旧归属草稿转换成一个授予批次；转换过程不再编码 JSON。
    func applyVestings(_ values: [StockVesting]) {
        let sum = values.reduce(Decimal.zero) { $0 + Decimal($1.sharesHundredths) }
        guard sum <= Decimal(ProfileRules.maximumMoneyCents) else { return }
        let grants: [EquityGrant] = values.isEmpty ? [] : [EquityGrant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "原有归属计划",
            date: min(baselineDate, values.map(\.date).min()!), shares: NSDecimalNumber(decimal: sum).int64Value,
            installments: values.map { EquityInstallment(id: $0.id, date: $0.date, shares: $0.sharesHundredths) })]
        applyGrants(grants)
    }
}

@Model final class EquityGrantRecord {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: UUID = UUID()
    /// 子记录最近修改时间，用于归并跨设备迁移产生的同源副本。
    var modifiedAt: Date = Date()
    /// 名称。
    var name: String = ""
    /// 日期。
    var date: Date = Date()
    /// 股票数量，单位为百分之一股。
    var shares: Int64 = 0
    /// 原始排列顺序，关联集合读取时据此还原顺序。
    var position: Int = 0
    /// 所属股票持仓，作为持仓关联的反向关系。
    var holding: StockHolding?
    /// 该记录拥有的分期明细；删除所属记录时级联删除。
    @Relationship(deleteRule: .cascade, inverse: \EquityInstallmentRecord.grant)
    var installmentRecords: [EquityInstallmentRecord]?
    /// 预期归属分期数量，防止云端只同步了部分明细时参与计算。
    var installmentCount: Int = 0
    init() {}
    /// 用于计算和编辑的值类型快照。
    var value: EquityGrant? {
        let records = Dictionary(grouping: (installmentRecords ?? []), by: \.id).values.compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
        guard records.count == installmentCount else { return nil }
        return EquityGrant(id: id, name: name, date: date, shares: shares,
            installments: records.sorted { $0.position < $1.position }.map(\.value))
    }
    func applyInstallments(_ values: [EquityInstallment], at date: Date = Date()) {
        let old = installmentRecords ?? []
        let records = values.enumerated().map { position, value in
            let record = old.filter { $0.id == value.id }.max { $0.modifiedAt < $1.modifiedAt } ?? EquityInstallmentRecord()
            record.modifiedAt = date
            record.id = value.id; record.date = value.date; record.shares = value.shares
            record.cancelled = value.cancelled; record.position = position
            return record
        }
        installmentRecords = records
        installmentCount = values.count
        for record in old where !records.contains(where: { $0 === record }) { modelContext?.delete(record) }
    }
}

@Model final class EquityInstallmentRecord {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: UUID = UUID()
    /// 子记录最近修改时间，用于归并跨设备迁移产生的同源副本。
    var modifiedAt: Date = Date()
    /// 日期。
    var date: Date = Date()
    /// 股票数量，单位为百分之一股。
    var shares: Int64 = 0
    /// 该期归属是否已取消，取消后保留历史但不再计值。
    var cancelled: Bool = false
    /// 原始排列顺序，关联集合读取时据此还原顺序。
    var position: Int = 0
    /// 所属股票授予批次，作为批次关联的反向关系。
    var grant: EquityGrantRecord?
    init() {}
    /// 用于计算和编辑的值类型快照。
    var value: EquityInstallment { EquityInstallment(id: id, date: date, shares: shares, cancelled: cancelled) }
}

@Model final class EquityDisposalRecord {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: UUID = UUID()
    /// 子记录最近修改时间，用于归并跨设备迁移产生的同源副本。
    var modifiedAt: Date = Date()
    /// 日期。
    var date: Date = Date()
    /// 股票数量，单位为百分之一股。
    var shares: Int64 = 0
    /// 原始排列顺序，关联集合读取时据此还原顺序。
    var position: Int = 0
    /// 所属股票持仓，作为持仓关联的反向关系。
    var holding: StockHolding?
    init() {}
    /// 用于计算和编辑的值类型快照。
    var value: EquityDisposal { EquityDisposal(id: id, date: date, shares: shares) }
}

enum StockRules {
    struct Value {
        /// 已归属股票数量，单位为百分之一股。
        let vestedShares: Int64
        /// 未归属股票数量，单位为百分之一股。
        let unvestedShares: Int64
        /// 已归属股票估值，单位为分。
        let vested: Int64
        /// 未归属股票估值，单位为分。
        let unvested: Int64
        /// 合计值。
        var total: Int64 { vested + unvested }
    }
    static func holdings(_ values: [StockHolding]) -> [StockHolding] {
        Dictionary(grouping: values, by: \.id).values.compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    struct Balance {
        /// 已归属股票数量，单位为百分之一股。
        let vestedShares: Int64
        /// 未归属股票数量，单位为百分之一股。
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
