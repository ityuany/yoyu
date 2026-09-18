import Foundation
import SwiftData

@MainActor
enum LiabilityStore {
    static func save(_ snapshot: LiabilitySnapshot, name: String, kind: LiabilityKind, account: LiabilityAccount?, reason: String, context: ModelContext) throws {
        guard LiabilityRules.error(snapshot, kind: kind) == nil,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LiabilitySaveError.invalidInput }
        let encoded = try JSONEncoder().encode(snapshot)
        var history: [LiabilityRevision] = []
        if let account {
            guard let previous = account.snapshot, let existing = account.history else { throw CocoaError(.coderReadCorrupt) }
            history = existing + [.init(date: Date(), reason: reason, snapshot: previous)]
        }
        let encodedHistory = try JSONEncoder().encode(history)
        let record = account ?? LiabilityAccount()
        if account == nil { context.insert(record) }
        record.name = name; record.kindRaw = kind.rawValue; record.snapshotData = encoded
        record.historyData = encodedHistory; record.modifiedAt = Date()
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

enum LiabilitySaveError: LocalizedError {
    case invalidInput
    var errorDescription: String? { "记录不完整或金额不匹配，请核对后保存。" }
}
