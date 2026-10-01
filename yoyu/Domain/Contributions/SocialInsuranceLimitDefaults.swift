import Foundation

enum SocialInsuranceLimitDefaults {
    struct Entry {
        /// 年份。
        let year: Int
        /// 月份。
        let month: Int
        /// 下限金额，单位为元。
        let lower: Int64
        /// 上限金额，单位为元。
        let upper: Int64
        /// 资料依据状态。
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

}
