import Foundation
import SwiftData

extension LiabilityAccount {
    func apply(_ snapshot: LiabilitySnapshot, at date: Date = Date()) {
        balanceDate = snapshot.balanceDate; cardTotal = snapshot.cardTotal
        billDue = snapshot.billDue; billDate = snapshot.billDate; note = snapshot.note
        fixedInstallmentsOnly = snapshot.fixedInstallmentsOnly; cardRepaymentDay = snapshot.cardRepaymentDay
        let oldMortgages = mortgageRecords ?? []
        let mortgages = snapshot.mortgages.enumerated().map { position, value in
            let record = oldMortgages.filter { $0.id == value.id }.max { $0.modifiedAt < $1.modifiedAt } ?? MortgagePartRecord()
            record.apply(value); record.modifiedAt = date; record.position = position
            return record
        }
        mortgageRecords = mortgages
        for record in oldMortgages where !mortgages.contains(where: { $0 === record }) { modelContext?.delete(record) }
        let oldInstallments = installmentRecords ?? []
        let installments = snapshot.installments.enumerated().map { position, value in
            let record = oldInstallments.filter { $0.id == value.id }.max { $0.modifiedAt < $1.modifiedAt } ?? CardInstallmentRecord()
            record.apply(value); record.modifiedAt = date; record.position = position
            return record
        }
        installmentRecords = installments
        for record in oldInstallments where !installments.contains(where: { $0 === record }) { modelContext?.delete(record) }
        mortgageCount = snapshot.mortgages.count
        installmentCount = snapshot.installments.count
        hasStructuredSnapshot = true
    }
}

extension LiabilityAccount {
    /// 负债类别。
    var kind: LiabilityKind? { LiabilityKind(rawValue: kindRaw) }

    /// 负债资料的值类型快照。
    var snapshot: LiabilitySnapshot? {
        if hasStructuredSnapshot {
            guard Set((mortgageRecords ?? []).map(\.id)).count == mortgageCount,
                  Set((installmentRecords ?? []).map(\.id)).count == installmentCount else { return nil }
            let installments = Dictionary(grouping: (installmentRecords ?? []), by: \.id).values.compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }.sorted { $0.position < $1.position }
            guard installments.allSatisfy({ !$0.hasTerms || InstallmentRateMode(rawValue: $0.rateModeRaw) != nil }) else { return nil }
            let mortgages = Dictionary(grouping: (mortgageRecords ?? []), by: \.id).values.compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }.sorted { $0.position < $1.position }
            guard mortgages.allSatisfy({ MortgageMethod(rawValue: $0.methodRaw) != nil }) else { return nil }
            return LiabilitySnapshot(balanceDate: balanceDate, mortgages: mortgages.map(\.value),
                cardTotal: cardTotal, billDue: billDue, billDate: billDate, installments: installments.map(\.value),
                note: note, fixedInstallmentsOnly: fixedInstallmentsOnly, cardRepaymentDay: cardRepaymentDay)
        }
        guard let snapshotData else { return nil }
        return try? JSONDecoder().decode(LiabilitySnapshot.self, from: snapshotData)
    }
}
