import Foundation
import SwiftData

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

extension StockHolding {
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
