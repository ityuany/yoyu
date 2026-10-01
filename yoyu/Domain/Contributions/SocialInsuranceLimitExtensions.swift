import Foundation

extension SocialInsuranceLimit {
    /// 资料依据状态。
    var evidence: LimitEvidence { LimitEvidence(rawValue: evidenceRaw) ?? .unverified }
}
