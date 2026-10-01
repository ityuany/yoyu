import Foundation
import SwiftData

extension RunwaySettings {
    /// 方案或配置。
    var plan: RunwayPlan? {
        if hasStructuredPlan {
            guard let mode = RunwayMode(rawValue: mode) else { return nil }
            return RunwayPlan(mode: mode, lossDate: lossDate, returnDate: returnDate, salary: salary,
                payday: payday, flexible: flexible, flexibleDay: flexibleDay)
        }
        return data.flatMap { try? JSONDecoder().decode(RunwayPlan.self, from: $0) }
    }

    func apply(_ plan: RunwayPlan) {
        mode = plan.mode.rawValue; lossDate = plan.lossDate; returnDate = plan.returnDate
        salary = plan.salary; payday = plan.payday; flexible = plan.flexible; flexibleDay = plan.flexibleDay
        hasStructuredPlan = true
    }
}
