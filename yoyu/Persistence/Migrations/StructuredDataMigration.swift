import Foundation
import SwiftData

/// 将旧 JSON 内容迁入字段和关联记录；只处理尚未转换的记录。
/// 保留旧字段，不删除用户资料；所有转换在同一次保存中提交，失败整体回滚。
@MainActor enum StructuredDataMigration {
    static func run(context: ModelContext) throws {
        do {
            for record in try context.fetch(FetchDescriptor<RecurringExpense>()) {
                if !record.hasStructuredPlan, let plan = record.plan { record.apply(plan) }
            }
            for record in try context.fetch(FetchDescriptor<RunwaySettings>()) {
                if !record.hasStructuredPlan, let plan = record.plan { record.apply(plan) }
            }
            for job in try context.fetch(FetchDescriptor<Employment>()) {
                if !job.hasStructuredSeverance, job.severanceData != nil,
                   let settings = SeveranceRules.settings(for: job) { job.applySeverance(settings) }
            }
            for holding in try context.fetch(FetchDescriptor<StockHolding>()) {
                if !holding.hasStructuredGrants, let grants = holding.grants { holding.applyGrants(grants, at: holding.modifiedAt) }
                if !holding.hasStructuredDisposals, let disposals = holding.disposals { holding.applyDisposals(disposals, at: holding.modifiedAt) }
            }
            for account in try context.fetch(FetchDescriptor<LiabilityAccount>()) {
                if !account.hasStructuredSnapshot, let snapshot = account.snapshot { account.apply(snapshot, at: account.modifiedAt) }
            }
            if context.hasChanges { try context.save() }
        } catch {
            context.rollback()
            throw error
        }
    }
}
