import Foundation

@main struct InvestmentProjectionTests {
    static func main() {
        func amount(_ months: Int, _ mode: InvestmentInterestMode, rate: Int64 = 500, principal: Int64 = 10_000_000) -> Int64? {
            InvestmentProjection.calculate(principal: principal, rate: rate, months: months, mode: mode)?.totalCents
        }
        precondition(amount(3, .simple) == 10_125_000)
        precondition(amount(6, .compound) == 10_250_000)
        precondition(amount(12, .simple) == amount(12, .compound))
        precondition(amount(36, .simple) == 11_500_000)
        precondition(amount(36, .compound) == 11_576_250)
        precondition(amount(18, .compound) == 10_762_500)
        precondition(amount(12, .compound, rate: -500) == 9_500_000)
        precondition(amount(36, .simple, rate: -10_000) == 0)
        precondition(amount(3, .compound, rate: -10_000) == 7_500_000)
        precondition(amount(24, .compound, rate: -10_000) == 0)
        precondition(amount(120, .compound, rate: 0) == 10_000_000)
        precondition(amount(1200, .compound, principal: 0) == 0)
        precondition(amount(1200, .compound, rate: 10_000) == nil)
        precondition(amount(1201, .simple) == nil)
        precondition(amount(-1, .simple) == nil)
        precondition(amount(12, .simple, rate: 10_001) == nil)
        precondition(amount(12, .simple, principal: -1) == nil)
        precondition(amount(6, .simple, rate: 100, principal: 100) == 101)
        precondition(InvestmentProjection.calculate(principal: nil, rate: 500, months: 12, mode: .simple) == nil)
        precondition(InvestmentProjection.calculate(principal: 100, rate: nil, months: 12, mode: .simple) == nil)
        precondition(InvestmentProjection.presets == [3, 6, 12, 36, 60, 96, 120])
        let start = ProfileRules.calendar.startOfDay(for: ProfileRules.date(2024, 1, 1))
        let year: TimeInterval = 365 * 24 * 60 * 60
        func live(_ elapsed: TimeInterval, compound: Bool = false, rate: Int64? = 500, principal: Int64? = 10_000_000, registration: Date? = start) -> Int64? {
            ProfileRules.investmentValue(principal: principal, rate: rate, registration: registration,
                                         compound: compound, on: start.addingTimeInterval(elapsed))
        }
        precondition(live(0) == 10_000_000)
        precondition(live(-1) == 10_000_000)
        precondition(live(year) == 10_500_000)
        precondition(live(year * 2) == 11_000_000)
        precondition(live(year * 2, compound: true) == 11_025_000)
        precondition(live(year * 2.5, compound: true) == 11_300_625)
        precondition(live(year, rate: -500) == 9_500_000)
        precondition(live(year * 2, rate: -10_000) == 0)
        precondition(live(year * 2, compound: true, rate: -10_000) == 0)
        precondition(live(year, principal: nil) == nil)
        precondition(live(year, rate: nil) == 10_000_000)
        precondition(live(year, registration: nil) == 10_000_000)
        precondition(live(year, rate: 0) == 10_000_000)
        precondition(live(year, rate: 10_001) == nil)
        precondition(live(year, principal: ProfileRules.maximumMoneyCents) == nil)
        precondition(live(1, rate: 10_000, principal: 1_000_000_000)! > live(0, rate: 10_000, principal: 1_000_000_000)!)
        precondition(live(year) == live(year), "Reading estimates must be deterministic")
        // Date selection means midnight, including a leap-year date; year length stays 365 days.
        precondition(live(year, registration: start.addingTimeInterval(43200)) == 10_500_000)
        print("InvestmentProjectionTests passed")
    }
}
