import Foundation

@main struct VestingTimelineTests {
    static func main() throws {
        let now = ProfileRules.date(2026, 9, 13)
        let next = ProfileRules.date(2027, 1, 1)
        let later = ProfileRules.date(2028, 1, 1)
        let a = StockHolding()
        a.priceCents = 200
        a.grantData = try JSONEncoder().encode([
            EquityGrant(name: "A", date: now, shares: 1000, installments: [
                EquityInstallment(date: now, shares: 100),
                EquityInstallment(date: next, shares: 200),
                EquityInstallment(date: next.addingTimeInterval(3600), shares: 100),
                EquityInstallment(date: later, shares: 200),
                EquityInstallment(date: later, shares: 100, cancelled: true)])])
        let b = StockHolding()
        b.currency = "HKD"; b.yuanRate = 0.5; b.priceCents = 400
        b.grantData = try JSONEncoder().encode([EquityGrant(name: "B", date: now, shares: 100, installments: [EquityInstallment(date: next, shares: 100)])])
        let plan = VestingTimeline.schedule([a, b, a], on: now)
        precondition(plan.days.count == 2)
        precondition(plan.days[0].companyCount == 2 && plan.days[0].batchCount == 2)
        precondition(plan.days[0].yuan == 800 && plan.days[1].yuan == 400)
        precondition(plan.unallocated[0].shares == 300 && plan.unallocated[0].yuan == 600)
        precondition(VestingTimeline.schedule([a, b], on: next).days.count == 1)
        b.priceIsConfigured = false
        precondition(VestingTimeline.schedule([a, b], on: now).days[0].yuan == nil)
        b.priceIsConfigured = true; b.priceCents = 0
        precondition(VestingTimeline.schedule([a, b], on: now).days[0].yuan == 600)
        precondition(VestingTimeline.sum([ProfileRules.maximumMoneyCents, 1]) == nil)
        b.grantData = Data([0])
        precondition(VestingTimeline.schedule([a, b], on: now).invalidCompanies == 1)
        precondition(VestingTimeline.schedule([], on: now).days.isEmpty)
        print("Vesting timeline: day grouping, year ordering, FX, cancelled/due exclusion, unallocated, missing/zero price, dedup and overflow passed")
    }
}
