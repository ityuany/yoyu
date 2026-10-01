import Foundation
import SwiftData

extension EquityDisposalRecord {
    /// 用于计算和编辑的值类型快照。
    var value: EquityDisposal { EquityDisposal(id: id, date: date, shares: shares) }
}
