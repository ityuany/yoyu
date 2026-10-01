import Foundation
import SwiftData

@Model
final class WorkdayOverride {
    /// 日期标识，采用年-月-日格式。
    var dateKey: String = ""
    /// 该日期是否由用户指定为工作日。
    var isWorkday: Bool = false
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()

    init(dateKey: String, isWorkday: Bool) {
        self.dateKey = dateKey
        self.isWorkday = isWorkday
    }
}
