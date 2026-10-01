import Foundation
import SwiftData

@Model
final class HousingFundLimit {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 适用城市。
    var city: String = "南京市"
    /// 生效月份，以月初日期表示。
    var effectiveMonth: Date = Date()
    /// 缴纳基数下限，单位为分。
    var lowerCents: Int64 = 0
    /// 缴纳基数上限，单位为分。
    var upperCents: Int64 = 0
    /// 资料依据状态的原始枚举值。
    var evidenceRaw: String = LimitEvidence.unverified.rawValue
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()

    init() {}
    /// 资料依据状态。
    var evidence: LimitEvidence { LimitEvidence(rawValue: evidenceRaw) ?? .unverified }
}

/// 与默认记录同步，避免删除后再次导入。
@Model
final class HousingFundLimitSeedState {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = "nanjing-housing-limits-v1"
    /// 默认资料导入时间。
    var importedAt: Date = Date()
    init() {}
}

enum HousingFundLimitDefaults {
    struct Entry {
        /// 年份。
        let year: Int
        /// 月份。
        let month: Int
        /// 下限金额，单位为元。
        let lower: Int64
        /// 上限金额，单位为元。
        let upper: Int64
    }

    // 南京住房公积金管理中心「历年缴存基数一览表」；年中下限调整按实际生效月拆分。
    // https://gjj.nanjing.gov.cn/bmxgj/jcsxxbg/202008/t20200819_2374481.html
    /// 按输入版本缓存的预测结果，仅保存在内存中。
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
