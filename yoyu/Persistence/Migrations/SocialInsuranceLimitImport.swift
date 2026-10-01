import Foundation
import SwiftData

/// 数据库操作保留原调用入口，集中由持久化层负责。
extension SocialInsuranceLimitDefaults {
    @MainActor static func importIfNeeded(context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<SocialInsuranceLimitSeedState>()) == 0 else { return }
        let existing = try context.fetch(FetchDescriptor<SocialInsuranceLimit>())
        let existingIDs = Set(existing.map(\.id))
        for entry in entries {
            let id = "nanjing-\(entry.year)-\(String(format: "%02d", entry.month))"
            guard !existingIDs.contains(id) else { continue }
            let record = SocialInsuranceLimit()
            record.id = id
            record.effectiveMonth = ProfileRules.date(entry.year, entry.month, 1)
            record.lowerCents = entry.lower * 100
            record.upperCents = entry.upper * 100
            record.evidenceRaw = entry.evidence.rawValue
            context.insert(record)
        }
        context.insert(SocialInsuranceLimitSeedState())
        try context.save()
    }
}
