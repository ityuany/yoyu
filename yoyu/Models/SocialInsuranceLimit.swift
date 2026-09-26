import Foundation
import SwiftData

enum LimitEvidence: String, CaseIterable, Identifiable {
    case official, provisional, unverified

    var id: String { rawValue }
    var title: String {
        switch self {
        case .official: "正式"
        case .provisional: "暂行"
        case .unverified: "待核"
        }
    }
    var symbol: String {
        switch self {
        case .official: "✅"
        case .provisional: "🟡"
        case .unverified: "❓"
        }
    }
}

@Model
final class SocialInsuranceLimit {
    var id: String = UUID().uuidString
    var city: String = "南京市"
    var effectiveMonth: Date = Date()
    var lowerCents: Int64 = 0
    var upperCents: Int64 = 0
    var evidenceRaw: String = LimitEvidence.unverified.rawValue
    var modifiedAt: Date = Date()

    init() {}
    var evidence: LimitEvidence { LimitEvidence(rawValue: evidenceRaw) ?? .unverified }
}

/// 与默认记录一同同步，避免用户删除内置记录后下次启动又被补回。
@Model
final class SocialInsuranceLimitSeedState {
    var id: String = "nanjing-limits-v1"
    var importedAt: Date = Date()
    init() {}
}

enum SocialInsuranceLimitDefaults {
    struct Entry {
        let year: Int
        let month: Int
        let lower: Int64
        let upper: Int64
        let evidence: LimitEvidence
    }

    // 从 2010 年 1 月起按生效月登记；后续记录出现前沿用上一条。
    // 2010 年初沿用的旧标准及 2010—2016 年缺少官网原文的行均标为待核。
    static let entries: [Entry] = [
        .init(year: 2010, month: 1, lower: 1455, upper: 9042, evidence: .unverified),
        .init(year: 2010, month: 10, lower: 1583, upper: 10905, evidence: .unverified),
        .init(year: 2011, month: 7, lower: 1794, upper: 12195, evidence: .unverified),
        .init(year: 2012, month: 7, lower: 1973, upper: 13678, evidence: .unverified),
        .init(year: 2013, month: 7, lower: 2200, upper: 13678, evidence: .official),
        .init(year: 2014, month: 7, lower: 2400, upper: 16200, evidence: .unverified),
        .init(year: 2015, month: 7, lower: 2628, upper: 16200, evidence: .unverified),
        .init(year: 2016, month: 7, lower: 2628, upper: 16800, evidence: .unverified),
        .init(year: 2017, month: 7, lower: 2772, upper: 18171, evidence: .official),
        .init(year: 2018, month: 7, lower: 3030, upper: 19935, evidence: .official),
        .init(year: 2019, month: 7, lower: 3368, upper: 16842, evidence: .official),
        .init(year: 2020, month: 7, lower: 3368, upper: 19335, evidence: .official),
        .init(year: 2021, month: 7, lower: 3800, upper: 20586, evidence: .official),
        .init(year: 2022, month: 1, lower: 4250, upper: 22470, evidence: .official),
        .init(year: 2023, month: 1, lower: 4494, upper: 24042, evidence: .provisional),
        .init(year: 2024, month: 1, lower: 4879, upper: 24396, evidence: .official),
        .init(year: 2025, month: 1, lower: 4952, upper: 24762, evidence: .official),
        .init(year: 2026, month: 1, lower: 4952, upper: 24762, evidence: .provisional)
    ]

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
