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

    func investmentValue(on date: Date) -> Int64? {
        guard ["单利", "复利"].contains(investmentInterestMode) else { return nil }
        return ProfileRules.investmentValue(principal: investmentCents,
                                            rate: investmentAnnualReturnBasisPoints,
                                            registration: investmentRegistrationDate,
                                            compound: investmentInterestMode == "复利", on: date)
    }

    /// 法定退休时间展示文字。
    var retirement: String {
        ProfileRules.statutoryRetirement(year: birthYear, month: birthMonth, gender: gender, femaleAge: femaleRetirementAge)
    }

    /// 股票估值，单位为分。
    var stockValueCents: Int64? {
        if stockSharesHundredths != nil || stockPriceCents != nil {
            return ProfileRules.stockValue(sharesHundredths: stockSharesHundredths, priceCents: stockPriceCents)
        }
        // Preserve amounts entered before share quantity and price were introduced.
        return stockCents
    }

    /// 已登记财富总额，单位为分。
    var totalWealth: Int64? {
        guard cashCents != nil || stockValueCents != nil || investmentCents != nil else { return nil }
        // 未填写的资产不等同于错误，汇总时按 0 处理；三个项目都未填才不显示总额。
        let investment = investmentValue(on: Date())
        if investmentCents != nil && investment == nil { return nil }
        return (cashCents ?? 0) + (stockValueCents ?? 0) + (investment ?? 0)
    }
}

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

extension UserProfile {
    /// Regular weekly schedule backed by `workweekMask`.
    /// 每周工作日安排。
    var workweek: Workweek {
        get { Workweek(mask: workweekMask) }
        set { workweekMask = newValue.mask }
    }

    func updatedAt(for section: ProfileSection) -> Date {
        switch section {
        case .basic: basicUpdatedAt ?? .distantPast
        case .employment: employmentUpdatedAt ?? .distantPast
        case .wealth: wealthUpdatedAt ?? .distantPast
        case .work: workUpdatedAt ?? .distantPast
        }
    }
}

enum ProfileSection: String, Identifiable {
    case basic = "基本信息"
    case employment = "企业信息"
    case work = "工作安排"
    case wealth = "当前财富"
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String { rawValue }
}
