import Foundation
import SwiftData

@Model
final class BonusPayment {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 所属任职记录的业务标识。
    var employmentID: String = ""
    // Older salary stages never recorded which year a payment belonged to.
    // They remain visible for review, but do not enter totals until dated.
    /// 所属年份，空值表示旧记录尚未确认年份。
    var year: Int?
    /// 所属月份。
    var month: Int = 12
    /// 金额，单位为分。
    var amountCents: Int64?
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    init() {}
}
