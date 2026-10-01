import Foundation

struct MortgagePart: Codable, Identifiable {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id = UUID()
    /// 名称。
    var name = "商业贷款"
    /// 本金，单位为分。
    var principal: Int64 = 0
    /// 贷款年利率，以百分数表示。
    var annualPercent: Double = 0
    /// 还款期数，单位为月。
    var months: Int = 240
    /// 房贷还款方式。
    var method: MortgageMethod = .annuity
    /// 下一期还款日期。
    var nextDate = Date()
    /// 每月扣款或还款日，短月份按月末处理。
    var dueDay = 1
    /// Optional bank-confirmed monthly principal for equal-principal loans.
    /// 银行确认的每期本金，单位为分，空值表示按规则计算。
    var fixedPrincipal: Int64?
}

struct FixedInstallmentTerms: Codable {
    /// 分期费率，以百分数表示。
    var rate: Double = 0
    /// 预测就业模式的原始枚举值。
    var mode: InstallmentRateMode = .annual
    /// 用户确认的已还期数。
    var paid: Int = 0
    /// nil preserves manually confirmed progress from earlier app versions.
    /// 是否自动推进已还期数，空值保留旧版手动进度语义。
    var automatic: Bool?
}

struct CardInstallment: Codable, Identifiable {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id = UUID()
    /// 名称。
    var name = ""
    /// 本金，单位为分。
    var principal: Int64 = 0
    /// 还款期数，单位为月。
    var months: Int = 12
    /// 下一期还款日期。
    var nextDate = Date()
    /// 每月扣款或还款日，短月份按月末处理。
    var dueDay = 1
    /// 银行确认的每期本金，单位为分，空值表示按规则计算。
    var fixedPrincipal: Int64?
    /// 每期手续费，单位为分。
    var monthlyFee: Int64 = 0
    /// 首期手续费，单位为分，空值表示使用常规每期费用。
    var firstFee: Int64?
    /// 末期手续费，单位为分，空值表示使用常规每期费用。
    var lastFee: Int64?
    /// 固定分期费率与进度配置。
    var terms: FixedInstallmentTerms?
}

struct LiabilitySnapshot: Codable {
    /// 负债余额登记日期。
    var balanceDate = Date()
    /// 房贷组成部分。
    var mortgages: [MortgagePart] = []
    /// Bank's total outstanding, including all installment principal and posted charges.
    /// 信用卡总欠款，包含分期本金及已入账费用，单位为分。
    var cardTotal: Int64 = 0
    /// 本期应还账单金额，单位为分，空值表示尚未确认。
    var billDue: Int64?
    /// 本期账单到期日期。
    var billDate = Date()
    /// 分期明细。
    var installments: [CardInstallment] = []
    /// 用户备注。
    var note = ""
    /// 是否已确认仅计算固定分期，空值表示旧资料未确认。
    var fixedInstallmentsOnly: Bool?
    /// 信用卡每月还款日。
    var cardRepaymentDay: Int?
}
