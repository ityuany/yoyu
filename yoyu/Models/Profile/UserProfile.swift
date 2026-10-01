import Foundation
import SwiftData

@Model
final class UserProfile {
    /// 旧企业资料是否已迁入任职记录。
    var careerMigrated: Bool = false
    /// 旧股票资料是否已完成核对迁入。
    var stockMigrated: Bool = false
    /// 女性原法定退休年龄类别，单位为岁。
    var femaleRetirementAge: Int?
    /// 资料创建时间。
    var createdAt: Date = Date()
    /// 基本信息最近修改时间。
    var basicUpdatedAt: Date?
    /// 旧企业资料最近修改时间。
    var employmentUpdatedAt: Date?
    /// 财富资料最近修改时间。
    var wealthUpdatedAt: Date?
    /// 旧工作安排最近修改时间。
    var workUpdatedAt: Date?
    /// 出生年份。
    var birthYear: Int?
    /// 出生月份，范围为 1 至 12。
    var birthMonth: Int?
    /// 性别。
    var gender: String = ""
    /// 旧企业资料中的入职日期。
    var hireDate: Date?
    /// 税前月薪，单位为分。
    var salaryCents: Int64?
    /// 个人养老保险缴纳比例，单位为基点，100 基点等于 1%。
    var pensionBasisPoints: Int64?
    /// 个人公积金缴纳比例，单位为基点，100 基点等于 1%。
    var housingBasisPoints: Int64?
    /// 旧年终奖金额，单位为分。
    var bonusCents: Int64?
    /// 旧年终奖发放月份。
    var bonusMonth: Int = 12
    /// 现金余额，单位为分。
    var cashCents: Int64?
    /// 旧版股票估值，单位为分。
    var stockCents: Int64?
    /// 旧版股票数量，单位为百分之一股。
    var stockSharesHundredths: Int64?
    /// 旧版股票单价，单位为分。
    var stockPriceCents: Int64?
    /// 登记的理财本金，单位为分。
    var investmentCents: Int64?
    /// 理财年化收益率，单位为基点，可为负值。
    var investmentAnnualReturnBasisPoints: Int64?
    /// 理财本金登记日期。
    var investmentRegistrationDate: Date?
    /// 理财计息方式，保存单利或复利。
    var investmentInterestMode: String = "单利"
    /// 每周工作日的位掩码。
    var workweekMask: Int = Workweek.default.mask
    /// 上班时间距零点的分钟数。
    var startMinutes: Int = 540
    /// 下班时间距零点的分钟数。
    var endMinutes: Int = 1080
    /// 是否遵循法定节假日及调休。
    var followsHolidays: Bool = true

    init() {}

}
