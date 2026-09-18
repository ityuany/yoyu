import Foundation

enum SeverancePlan: String, Codable, CaseIterable, Identifiable {
    case n, nPlusOne, twoN, customAmount

    // 旧自定义金额仅保留读取兼容，不再提供新建入口。
    static let selectable: [Self] = [.n, .nPlusOne, .twoN]

    var id: String { rawValue }
    var title: String {
        switch self {
        case .n: "N"
        case .nPlusOne: "N+1"
        case .twoN: "2N"
        case .customAmount: "自定义金额"
        }
    }
}

struct SeveranceSettings: Codable, Equatable {
    var plan: SeverancePlan = .nPlusOne
    var baseSalaryCents: Int64?
    var noticeSalaryCents: Int64?
    var tenureHundredths: Int64?
    var customAmountCents: Int64?
}

/// 可调整的税前情景估算，不自动判定具体补偿资格、地区封顶或税费。
enum SeveranceRules {
    struct Estimate {
        let amountCents: Int64
        let tenureHundredths: Int64?
        let baseSalaryCents: Int64?
        let noticeSalaryCents: Int64?
    }

    static func settings(for job: Employment) -> SeveranceSettings? {
        guard let data = job.severanceData else { return SeveranceSettings() }
        return try? JSONDecoder().decode(SeveranceSettings.self, from: data)
    }

    static func tenureHundredths(start: Date?, on date: Date) -> Int64? {
        guard let start else { return nil }
        let calendar = ProfileRules.calendar
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: date)
        guard first <= last,
              let years = calendar.dateComponents([.year], from: first, to: last).year,
              (0...100).contains(years),
              let anniversary = calendar.date(byAdding: .year, value: years, to: first),
              let halfYear = calendar.date(byAdding: .month, value: 6, to: anniversary) else { return nil }
        let remainder: Int64
        if years > 0 && last == anniversary { remainder = 0 }
        else { remainder = last < halfYear ? 50 : 100 }
        let value = Int64(years) * 100 + remainder
        return value <= 10_000 ? value : nil
    }

    static func estimate(settings: SeveranceSettings, job: Employment, salaryCents: Int64?, on date: Date) -> Estimate? {
        guard job.isCurrent(on: date) else { return nil }
        if settings.plan == .customAmount {
            guard let amount = validMoney(settings.customAmountCents) else { return nil }
            return Estimate(amountCents: amount, tenureHundredths: nil, baseSalaryCents: nil, noticeSalaryCents: nil)
        }
        guard let tenure = settings.tenureHundredths ?? tenureHundredths(start: job.start, on: date),
              (0...10_000).contains(tenure),
              let base = validMoney(settings.baseSalaryCents ?? salaryCents) else { return nil }
        let notice: Int64?
        if settings.plan == .nPlusOne {
            guard let value = validMoney(settings.noticeSalaryCents ?? salaryCents) else { return nil }
            notice = value
        } else { notice = nil }
        let multiplier: Decimal = settings.plan == .twoN ? 2 : 1
        var amount = Decimal(base) * Decimal(tenure) / 100 * multiplier + Decimal(notice ?? 0)
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &amount, 0, .plain)
        guard rounded >= 0, rounded <= Decimal(ProfileRules.maximumMoneyCents) else { return nil }
        return Estimate(amountCents: NSDecimalNumber(decimal: rounded).int64Value,
                        tenureHundredths: tenure, baseSalaryCents: base, noticeSalaryCents: notice)
    }

    static func wealth(currentCents: Int64?, compensationCents: Int64?) -> Int64? {
        guard let current = validMoney(currentCents), let compensation = validMoney(compensationCents),
              current <= ProfileRules.maximumMoneyCents - compensation else { return nil }
        return current + compensation
    }

    private static func validMoney(_ value: Int64?) -> Int64? {
        guard let value, (0...ProfileRules.maximumMoneyCents).contains(value) else { return nil }
        return value
    }
}
