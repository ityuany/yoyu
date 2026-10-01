import Foundation
import SwiftData

extension EquityInstallmentRecord {
    /// 用于计算和编辑的值类型快照。
    var value: EquityInstallment { EquityInstallment(id: id, date: date, shares: shares, cancelled: cancelled) }
}
