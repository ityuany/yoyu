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
        print("InvestmentProjectionTests passed")
    }
}
