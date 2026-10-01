import Foundation
import SwiftData

extension CardInstallmentRecord {
    /// 用于计算和编辑的值类型快照。
    var value: CardInstallment { CardInstallment(id: id, name: name, principal: principal, months: months,
        nextDate: nextDate, dueDay: dueDay, fixedPrincipal: fixedPrincipal, monthlyFee: monthlyFee,
        firstFee: firstFee, lastFee: lastFee, terms: hasTerms ? FixedInstallmentTerms(rate: rate,
            mode: InstallmentRateMode(rawValue: rateModeRaw)!, paid: paid, automatic: automatic) : nil) }

    func apply(_ value: CardInstallment) {
        id = value.id; name = value.name; principal = value.principal; months = value.months
        nextDate = value.nextDate; dueDay = value.dueDay; fixedPrincipal = value.fixedPrincipal
        monthlyFee = value.monthlyFee; firstFee = value.firstFee; lastFee = value.lastFee
        hasTerms = value.terms != nil; rate = value.terms?.rate ?? 0
        rateModeRaw = value.terms?.mode.rawValue ?? "annual"; paid = value.terms?.paid ?? 0
        automatic = value.terms?.automatic
    }
}
