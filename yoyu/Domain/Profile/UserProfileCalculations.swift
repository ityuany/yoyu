import Foundation

extension UserProfile {
    func investmentValue(on date: Date) -> Int64? {
        guard ["单利", "复利"].contains(investmentInterestMode) else { return nil }
        return ProfileRules.investmentValue(principal: investmentCents,
                                            rate: investmentAnnualReturnBasisPoints,
                                            registration: investmentRegistrationDate,
                                            compound: investmentInterestMode == "复利", on: date)
    }

    /// 法定退休时间展示文字。
    var retirement: String {
        ProfileRules.statutoryRetirement(year: birthYear, month: birthMonth, gender: gender, femaleAge: femaleRetirementAge)
    }

    /// 股票估值，单位为分。
    var stockValueCents: Int64? {
        if stockSharesHundredths != nil || stockPriceCents != nil {
            return ProfileRules.stockValue(sharesHundredths: stockSharesHundredths, priceCents: stockPriceCents)
        }
        // Preserve amounts entered before share quantity and price were introduced.
        return stockCents
    }

}
