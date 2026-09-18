import Foundation
import SwiftData

@MainActor enum ExpenseStore {
    static func save(_ plan: ExpensePlan, record: RecurringExpense?, context: ModelContext) throws {
        if let error = ExpenseRules.error(plan) { throw ExpenseSaveError.invalid(error) }
        var clean = plan
        clean.name = plan.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = try JSONEncoder().encode(clean)
        let item = record ?? RecurringExpense()
        if record == nil { context.insert(item) }
        item.planData = data
        item.modifiedAt = Date()
        do { try context.save() } catch { context.rollback(); throw error }
    }
    static func delete(id: String, context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<RecurringExpense>())
        for record in records where record.id == id { context.delete(record) }
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

enum ExpenseSaveError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): message } }
}
