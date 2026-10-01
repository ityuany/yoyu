import Foundation
import SwiftData

extension RecurringExpense {
    /// 方案或配置。
    var plan: ExpensePlan? {
        if hasStructuredPlan {
            guard let frequency = ExpenseFrequency(rawValue: frequencyRaw) else { return nil }
            return ExpensePlan(name: name, amount: amount, estimated: estimated, frequency: frequency,
                start: start, end: end, spreadAcrossMonth: spreadAcrossMonth, dueDay: dueDay,
                note: note, coveredByLiabilityID: coveredByLiabilityID, pausesDuringWorkBreak: pausesDuringWorkBreak)
        }
        guard let planData else { return nil }
        return try? JSONDecoder().decode(ExpensePlan.self, from: planData)
    }

    func apply(_ plan: ExpensePlan) {
        name = plan.name; amount = plan.amount; estimated = plan.estimated
        frequencyRaw = plan.frequency.rawValue; start = plan.start; end = plan.end
        spreadAcrossMonth = plan.spreadAcrossMonth; dueDay = plan.dueDay; note = plan.note
        coveredByLiabilityID = plan.coveredByLiabilityID; pausesDuringWorkBreak = plan.pausesDuringWorkBreak
        hasStructuredPlan = true
    }
}
