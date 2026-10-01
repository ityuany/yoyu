import Foundation
import SwiftData

extension EquityGrantRecord {
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
