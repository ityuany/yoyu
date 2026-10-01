import Foundation

extension Employment {
    /// 将补偿草稿写入独立字段，旧 JSON 仅保留作兼容资料。
    func applySeverance(_ settings: SeveranceSettings) {
        severancePlanRaw = settings.plan.rawValue
        severanceBaseSalaryCents = settings.baseSalaryCents
        severanceNoticeSalaryCents = settings.noticeSalaryCents
        severanceTenureHundredths = settings.tenureHundredths
        severanceCustomAmountCents = settings.customAmountCents
        severanceTripleAverageSalaryCents = settings.tripleAverageSalaryCents
        hasStructuredSeverance = true
    }
}
