import Foundation
import SwiftData

@main struct EquityTests {
    @MainActor static func main() throws {
        let day = ProfileRules.calendar.startOfDay(for: ProfileRules.date(2026, 5, 1))
        let future = ProfileRules.calendar.date(byAdding: .year, value: 1, to: day)!
        var grant = EquityGrant(name: "入职授予", date: day, shares: 400_000, installments: [EquityInstallment(date: day, shares: 100_000), EquityInstallment(date: future, shares: 100_000)])
        precondition(EquityRules.error(grant) == nil && EquityRules.unallocated(grant) == 200_000)
        precondition(EquityRules.vested(grant, on: day.addingTimeInterval(-1)) == 0)
        precondition(EquityRules.vested(grant, on: day) == 100_000)
        let holding = StockHolding()
        holding.priceCents = 10_000
        holding.employmentID = "company"
        holding.grantData = try JSONEncoder().encode([grant])
        precondition(StockRules.value(holding, on: day)?.unvestedShares == 300_000)
        precondition(StockRules.value(holding, on: future)?.vestedShares == 200_000)
        precondition(holding.priceIsConfigured)
        holding.priceIsConfigured = false
        precondition(StockRules.canSave(holding, on: day))
        precondition(StockRules.balance(holding, on: day)?.vestedShares == 100_000)
        precondition(StockRules.value(holding, on: day) == nil)
        precondition(StockRules.portfolio([holding], profile: nil, on: day) == nil)
        precondition(StockRules.wealth([holding], profile: nil, on: day) == nil)
        holding.priceIsConfigured = true
        holding.priceCents = 0
        precondition(StockRules.value(holding, on: day)?.total == 0)
        holding.priceCents = 10_000
        precondition(StockRules.value(holding, on: day)?.total == 40_000_000)
        grant.installments[1].cancelled = true
        holding.grantData = try JSONEncoder().encode([grant])
        precondition(StockRules.value(holding, on: future)?.vestedShares == 100_000)
        precondition(StockRules.value(holding, on: future)?.unvestedShares == 200_000)
        holding.disposalData = try JSONEncoder().encode([EquityDisposal(date: day, shares: 50_000)])
        precondition(StockRules.value(holding, on: day)?.vestedShares == 50_000)
        precondition(EquityRules.vested(holding.grants![0], on: day) == 100_000)
        holding.disposalData = try JSONEncoder().encode([EquityDisposal(date: day, shares: 200_000)])
        precondition(StockRules.value(holding, on: day) == nil)
        grant.shares = 10
        precondition(EquityRules.error(grant) != nil)
        let generated = EquityRules.generate(first: ProfileRules.date(2026, 1, 31), count: 3, months: 1, shares: 100)
        precondition(generated.count == 3 && ProfileRules.calendar.component(.day, from: generated[1].date) == 28)
        precondition(ProfileRules.calendar.component(.day, from: generated[2].date) == 31)
        precondition(EquityRules.generate(first: day, count: 121, months: 1, shares: 10).isEmpty)
        let old = StockHolding()
        old.baselineDate = day
        old.priceCents = 100
        old.initialSharesHundredths = 200
        old.vestingData = try JSONEncoder().encode([StockVesting(date: future, sharesHundredths: 300)])
        precondition(old.grants?.first?.name == "原有归属计划")
        precondition(StockRules.value(old, on: day)?.vestedShares == 200)
        precondition(StockRules.value(old, on: future)?.vestedShares == 500)
        old.grantData = try JSONEncoder().encode(old.grants!)
        precondition(StockRules.value(old, on: future)?.vestedShares == 500)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([StockHolding.self])
        let config = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("equity.store"), cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            old.employmentID = "existing-company"
            old.disposalData = try JSONEncoder().encode([EquityDisposal(date: day, shares: 100)])
            old.priceIsConfigured = false
            context.insert(old)
            try context.save()
            old.grantData = nil
            context.rollback()
            precondition(old.grantData != nil)
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let saved = try context.fetch(FetchDescriptor<StockHolding>())[0]
            precondition(saved.employmentID == "existing-company")
            precondition(saved.grants?.count == 1 && saved.disposals?.count == 1)
            precondition(!saved.priceIsConfigured)
            precondition(StockRules.balance(saved, on: future)?.vestedShares == 400)
            precondition(StockRules.canSave(saved, on: future))
            precondition(StockRules.value(saved, on: future) == nil)
        }
        print("Equity grant, unallocated shares, vesting, cancellation, disposals, periodic generation and legacy compatibility passed")
    }
}
