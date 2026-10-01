import Foundation
import SwiftData

enum RunwayStore {
    static func record(_ records: [RunwaySettings], mode: RunwayMode) -> RunwaySettings? {
        records.filter { $0.mode == mode.rawValue }.sorted {
            $0.modifiedAt == $1.modifiedAt ? $0.id > $1.id : $0.modifiedAt > $1.modifiedAt
        }.first
    }
    static func active(_ records: [RunwaySettings]) -> RunwayPlan? {
        records.sorted { $0.modifiedAt == $1.modifiedAt ? $0.id > $1.id : $0.modifiedAt > $1.modifiedAt }.first?.plan
    }
    @MainActor static func save(_ plan: RunwayPlan, records: [RunwaySettings], context: ModelContext) throws {
        let record = record(records, mode: plan.mode) ?? RunwaySettings()
        if record.modelContext == nil { context.insert(record) }
        record.apply(plan)
        record.modifiedAt = Date()
        do { try context.save() } catch { context.rollback(); throw error }
    }
}
