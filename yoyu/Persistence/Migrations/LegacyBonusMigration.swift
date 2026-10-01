import Foundation
import SwiftData

/// 数据库操作保留原调用入口，集中由持久化层负责。
extension BonusRules {
    @MainActor static func importLegacyStagePayments(context: ModelContext) throws {
        let stages = try context.fetch(FetchDescriptor<SalaryStage>())
        var existing = Set(try context.fetch(FetchDescriptor<BonusPayment>()).map(\.id))
        var changed = false
        for stage in stages {
            guard let amount = stage.bonusCents else { continue }
            let id = "salary-stage-bonus-\(stage.id)"
            if !existing.contains(id) {
                let payment = BonusPayment()
                payment.id = id
                payment.employmentID = stage.employmentID
                payment.month = stage.bonusMonth
                payment.amountCents = amount
                context.insert(payment)
                existing.insert(id)
            }
            stage.bonusCents = nil
            changed = true
        }
        guard changed else { return }
        do { try context.save() } catch { context.rollback(); throw error }
    }
}
