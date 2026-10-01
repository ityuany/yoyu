import Foundation
import SwiftData

// 冻结的旧版模型：单独编译以生成真实旧结构数据库，不与当前模型一同编译。
@Model
final class Employment {
    var id: String = UUID().uuidString
    var name: String = ""
    var start: Date?
    var end: Date?
    var modifiedAt: Date = Date()
    var followsHolidays: Bool = true
    var workweekMask: Int = 62
    var startMinutes: Int = 540
    var endMinutes: Int = 1080
    var salaryPaymentDay: Int = 10
    var severanceData: Data?
    init() {}
}

@Model final class StockHolding {
    var id: String = UUID().uuidString
    var name: String = ""
    var employmentID: String = ""
    var grantData: Data?
    var disposalData: Data?
    var currency: String = "CNY"
    var priceCents: Int64 = 0
    var priceIsConfigured: Bool = true
    var priceUpdatedAt: Date = Date()
    var yuanRate: Double = 1
    var baselineDate: Date = Date()
    var initialSharesHundredths: Int64 = 0
    // 同一份草稿整体保存，避免编辑取消时留下独立计划记录。
    var vestingData: Data?
    var modifiedAt: Date = Date()
    init() {}
}

@Model final class LiabilityAccount {
    var id: String = UUID().uuidString
    var name: String = ""
    var kindRaw: String = "mortgage"
    var snapshotData: Data?
    // Legacy persisted field retained for SwiftData / CloudKit compatibility; no longer read or written.
    var historyData: Data?
    var modifiedAt: Date = Date()
    init() {}
}

@Model final class RecurringExpense {
    var id: String = UUID().uuidString
    var planData: Data?
    var modifiedAt: Date = Date()
    init() {}
}

@Model final class RunwaySettings {
    var id: String = UUID().uuidString
    var mode: String = "employed"
    var data: Data?
    var modifiedAt: Date = Date()
    init() {}
}

