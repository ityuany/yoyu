import Foundation
import SwiftData

@Model
final class HousingFundLimit {
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

/// 与默认记录同步，避免删除后再次导入。
@Model
final class HousingFundLimitSeedState {
    var id: String = "nanjing-housing-limits-v1"
    var importedAt: Date = Date()
    init() {}
}

enum HousingFundLimitDefaults {
    struct Entry {
        let year: Int
        let month: Int
        let lower: Int64
        let upper: Int64
    }

    // 南京住房公积金管理中心「历年缴存基数一览表」；年中下限调整按实际生效月拆分。
    // https://gjj.nanjing.gov.cn/bmxgj/jcsxxbg/202008/t20200819_2374481.html
    static let entries: [Entry] = [
        .init(year: 2010, month: 7, lower: 960, upper: 10900),
        .init(year: 2011, month: 7, lower: 1140, upper: 12200),
        .init(year: 2012, month: 7, lower: 1320, upper: 13700),
        .init(year: 2013, month: 7, lower: 1480, upper: 15200),
        .init(year: 2014, month: 7, lower: 1480, upper: 16200),
        .init(year: 2014, month: 11, lower: 1630, upper: 16200),
        .init(year: 2015, month: 7, lower: 1630, upper: 18200),
        .init(year: 2016, month: 1, lower: 1770, upper: 18200),
        .init(year: 2016, month: 7, lower: 1770, upper: 20200),
        .init(year: 2017, month: 7, lower: 1890, upper: 22500),
        .init(year: 2018, month: 7, lower: 1890, upper: 25300),
        .init(year: 2018, month: 8, lower: 2020, upper: 25300),
        .init(year: 2019, month: 7, lower: 2020, upper: 27700),
        .init(year: 2020, month: 7, lower: 2020, upper: 31200),
        .init(year: 2021, month: 7, lower: 2020, upper: 34500),
        .init(year: 2021, month: 8, lower: 2280, upper: 34500),
        .init(year: 2022, month: 7, lower: 2280, upper: 37200),
        .init(year: 2023, month: 7, lower: 2280, upper: 38700),
        .init(year: 2024, month: 7, lower: 2490, upper: 39900),
        .init(year: 2025, month: 7, lower: 2490, upper: 41400),
        .init(year: 2026, month: 1, lower: 2660, upper: 41400),
        .init(year: 2026, month: 7, lower: 2660, upper: 42400)
    ]

    @MainActor static func importIfNeeded(context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<HousingFundLimitSeedState>()) == 0 else { return }
        let existing = try context.fetch(FetchDescriptor<HousingFundLimit>())
        let existingIDs = Set(existing.map(\.id))
        for entry in entries {
            let id = "nanjing-housing-\(entry.year)-\(String(format: "%02d", entry.month))"
            guard !existingIDs.contains(id) else { continue }
            let record = HousingFundLimit()
            record.id = id
            record.effectiveMonth = ProfileRules.date(entry.year, entry.month, 1)
            record.lowerCents = entry.lower * 100
            record.upperCents = entry.upper * 100
            record.evidenceRaw = LimitEvidence.official.rawValue
            context.insert(record)
        }
        context.insert(HousingFundLimitSeedState())
        try context.save()
    }
}
