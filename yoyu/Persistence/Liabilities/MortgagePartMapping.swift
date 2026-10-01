import Foundation
import SwiftData

extension MortgagePartRecord {
    /// 用于计算和编辑的值类型快照。
    var value: MortgagePart { MortgagePart(id: id, name: name, principal: principal, annualPercent: annualPercent,
        months: months, method: MortgageMethod(rawValue: methodRaw)!, nextDate: nextDate, dueDay: dueDay, fixedPrincipal: fixedPrincipal) }

    func apply(_ value: MortgagePart) {
        id = value.id; name = value.name; principal = value.principal; annualPercent = value.annualPercent
        months = value.months; methodRaw = value.method.rawValue; nextDate = value.nextDate
        dueDay = value.dueDay; fixedPrincipal = value.fixedPrincipal
    }
}
