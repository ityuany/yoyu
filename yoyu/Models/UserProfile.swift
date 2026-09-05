import Foundation
import SwiftData

@Model
final class UserProfile {
    var createdAt: Date = Date()
    var basicUpdatedAt: Date?
    var employmentUpdatedAt: Date?
    var wealthUpdatedAt: Date?
    var workUpdatedAt: Date?
    var birthYear: Int?
    var birthMonth: Int?
    var gender: String = ""
    var hireDate: Date?
    var salaryCents: Int64?
    var pensionBasisPoints: Int64?
    var housingBasisPoints: Int64?
    var bonusCents: Int64?
    var bonusMonth: Int = 12
    var cashCents: Int64?
    var stockCents: Int64?
    var stockSharesHundredths: Int64?
    var stockPriceCents: Int64?
    var investmentCents: Int64?
    var investmentAnnualReturnBasisPoints: Int64?
    var workweekMask: Int = Workweek.default.mask
    var startMinutes: Int = 540
    var endMinutes: Int = 1080
    var followsHolidays: Bool = true

    init() {}

    var retirement: String {
        guard let birthYear, let birthMonth, let age = ProfileRules.retirementAge(gender: gender) else { return "待完善" }
        return "\(birthYear + age) 年 \(birthMonth) 月"
    }

    var stockValueCents: Int64? {
        if stockSharesHundredths != nil || stockPriceCents != nil {
            return ProfileRules.stockValue(sharesHundredths: stockSharesHundredths, priceCents: stockPriceCents)
        }
        // Preserve amounts entered before share quantity and price were introduced.
        return stockCents
    }

    var totalWealth: Int64? {
        guard cashCents != nil || stockValueCents != nil || investmentCents != nil else { return nil }
        return (cashCents ?? 0) + (stockValueCents ?? 0) + (investmentCents ?? 0)
    }
}

@Model
final class WorkdayOverride {
    var dateKey: String = ""
    var isWorkday: Bool = false
    var modifiedAt: Date = Date()

    init(dateKey: String, isWorkday: Bool) {
        self.dateKey = dateKey
        self.isWorkday = isWorkday
    }
}

extension UserProfile {
    /// Regular weekly schedule backed by `workweekMask`.
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
    var id: String { rawValue }
}
