import Foundation

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
