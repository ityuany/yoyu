import Foundation
import SwiftData

/// 删除同一业务 ID 的全部副本，避免 CloudKit 归并后旧副本重新出现。
enum EmploymentDeletion {
    @MainActor static func delete(id: String, context: ModelContext, save: (ModelContext) throws -> Void = { try $0.save() }) throws {
        do {
            let jobs = try context.fetch(FetchDescriptor<Employment>()).filter { $0.id == id }
            let stages = try context.fetch(FetchDescriptor<SalaryStage>()).filter { $0.employmentID == id }
            let holdings = try context.fetch(FetchDescriptor<StockHolding>()).filter { $0.employmentID == id }
            for holding in holdings { context.delete(holding) }
            for stage in stages { context.delete(stage) }
            for job in jobs { context.delete(job) }
            try save(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
