import Foundation

struct EquityInstallmentDraft: Identifiable {
    /// 归属草稿标识。
    var id = UUID()
    /// 归属日期。
    var date = Date()
    /// 用户输入的归属股数。
    var quantity = ""
    /// 该期是否取消归属。
    var cancelled = false
}

