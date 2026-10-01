import Foundation

enum ContributionKind: Hashable {
    case pension, housing

    /// 展示标题。
    var title: String { self == .pension ? "养老保险" : "住房公积金" }
    /// 简短展示名称。
    var shortTitle: String { self == .pension ? "养老金" : "公积金" }
    func base(_ record: ContributionStage) -> Int64? { self == .pension ? record.pensionBaseCents : record.housingBaseCents }
    func rate(_ record: ContributionStage) -> Int64? { self == .pension ? record.pensionBasisPoints : record.housingBasisPoints }
    func hasValues(_ record: ContributionStage) -> Bool { base(record) != nil || rate(record) != nil }
}

struct ContributionEstimate {
    /// 金额，单位为分。
    let amountCents: Int64
    /// 纳入统计的月份数量。
    let coveredMonths: Int
}
