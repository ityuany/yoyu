import Foundation

/// Keeps uninvested earnings separate from the interest-bearing capital.
/// Redemptions consume earnings first, then capital. Compounding remains anchored
/// to the original registration's 365-day anniversaries, matching Wealth.
nonisolated struct RunwayInvestment: Sendable {
    /// 当前本金，单位为分。
    var capital: Decimal
    /// 累计收益。
    var earnings: Decimal
    /// 分期费率，以百分数表示。
    var rate: Decimal
    /// 是否采用复利。
    var compound: Bool
    /// 登记日期。
    var registration: Date
    /// 用于计算和编辑的值类型快照。
    var value: Decimal { max(0, capital + earnings) }

    @MainActor init?(profile: UserProfile?, on today: Date) {
        guard let profile, let principal = profile.investmentCents else { return nil }
        guard let total = profile.investmentValue(on: today) else { return nil }
        registration = ProfileRules.calendar.startOfDay(for: profile.investmentRegistrationDate ?? today)
        rate = Decimal(profile.investmentAnnualReturnBasisPoints ?? 0) / 10_000
        compound = profile.investmentInterestMode == "复利"
        let years = max(0, Int(today.timeIntervalSince(registration) / (365 * 86400)))
        capital = Decimal(principal)
        if compound { for _ in 0..<years { capital *= 1 + rate } }
        earnings = Decimal(total) - capital
    }
    mutating func advance(to day: Date) -> Decimal {
        guard day > registration, value > 0 else { return 0 }
        let before = value
        earnings += capital * rate / 365
        if capital + earnings < 0 { earnings = -capital }
        let elapsed = Int(day.timeIntervalSince(registration) / 86400)
        if compound && elapsed > 0 && elapsed % 365 == 0 {
            capital = value
            earnings = 0
        }
        return value - before
    }
    mutating func redeem(_ requested: Decimal) -> Decimal {
        let amount = min(max(0, requested), value)
        // A negative accrued return is allocated proportionally to capital.
        if earnings < 0 {
            let ratio = value > 0 ? (value - amount) / value : 0
            capital *= ratio
            earnings *= ratio
        } else {
            let interest = min(earnings, amount)
            earnings -= interest
            capital = max(0, capital - (amount - interest))
        }
        return amount
    }
}
