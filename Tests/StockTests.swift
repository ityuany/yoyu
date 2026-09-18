import Foundation
import SwiftData

@main struct StockTests {
    @MainActor static func main() throws {
        let calendar = ProfileRules.calendar
        let before = ProfileRules.date(2026, 9, 13)
        let due = calendar.startOfDay(for: ProfileRules.date(2027, 3, 1))
        let holding = StockHolding()
        holding.name = "测试股票"
        holding.initialSharesHundredths = 200_000
        holding.priceCents = 10_000
        holding.baselineDate = before
        holding.vestingData = try JSONEncoder().encode([
            StockVesting(date: due, sharesHundredths: 100_000),
            StockVesting(date: ProfileRules.date(2028, 3, 1), sharesHundredths: 200_000)
        ])
        let initial = StockRules.value(holding, on: before)!
        precondition(initial.vested == 20_000_000 && initial.unvested == 30_000_000 && initial.total == 50_000_000)
        precondition(StockRules.value(holding, on: due.addingTimeInterval(-1))?.vestedShares == 200_000)
        precondition(StockRules.value(holding, on: due)?.vestedShares == 300_000)
        precondition(StockRules.value(holding, on: due)?.total == initial.total)
        precondition(StockRules.value(holding, on: due)?.vestedShares == 300_000) // Repeated reads never mutate.
        precondition(holding.initialSharesHundredths == 200_000)
        let profile = UserProfile()
        profile.cashCents = 100_000
        profile.investmentCents = 200_000
        precondition(StockRules.wealth([holding], profile: profile, on: before) == 20_300_000)
        precondition(StockRules.wealth([holding], profile: profile, on: before, compensationCents: 3_000_000) == 23_300_000)
        precondition(StockRules.wealth([holding], profile: profile, on: before, compensationCents: 0) == 20_300_000)
        precondition(StockRules.wealth([], profile: nil, on: before, compensationCents: 3_000_000) == 3_000_000)
        precondition(StockRules.wealth([], profile: nil, on: before, compensationCents: 0) == 0)
        precondition(StockRules.wealth([], profile: nil, on: before) == nil)
        precondition(StockRules.wealth([holding], profile: profile, on: before, compensationCents: ProfileRules.maximumMoneyCents) == nil)
        precondition(StockRules.wealth([holding], profile: profile, on: before, compensationCents: -1) == nil)
        holding.priceIsConfigured = false
        precondition(StockRules.wealth([holding], profile: profile, on: before, compensationCents: 3_000_000) == nil)
        holding.priceIsConfigured = true
        holding.currency = "HKD"
        holding.yuanRate = 0.92
        precondition(StockRules.portfolio([holding], profile: profile, on: before) == 18_400_000)
        profile.stockCents = 50_000
        precondition(StockRules.portfolio([], profile: profile, on: before) == 50_000)
        precondition(StockRules.needsLegacyReview([holding], profile: profile))
        precondition(StockRules.portfolio([holding], profile: profile, on: before) == nil)
        precondition(StockRules.portfolio([holding], profile: profile, on: before, unvested: true) == nil)
        precondition(StockRules.wealth([holding], profile: profile, on: before) == nil)
        profile.stockMigrated = true
        precondition(!StockRules.needsLegacyReview([holding], profile: profile))
        precondition(StockRules.portfolio([holding], profile: profile, on: before) == 18_400_000)
        precondition(profile.stockCents == 50_000) // Reconciliation retains the original data.
        profile.stockMigrated = false
        holding.id = "legacy-stock-\(profile.createdAt.timeIntervalSince1970)"
        precondition(StockRules.portfolio([holding], profile: profile, on: before) == 18_400_000) // Sync ordering cannot double count legacy amount.
        precondition(!StockRules.needsLegacyReview([holding], profile: profile))
        profile.stockMigrated = true
        precondition(StockRules.legacy(profile) == nil)
        precondition(StockRules.holdings([holding, holding]).count == 1)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([StockHolding.self, UserProfile.self])
        let config = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("stocks.store"), cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            context.insert(holding)
            context.insert(profile)
            try context.save()
            holding.name = "取消的修改"
            context.rollback()
            precondition(holding.name == "测试股票")
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let saved = try context.fetch(FetchDescriptor<StockHolding>())[0]
            precondition(saved.vestings?.count == 2 && saved.currency == "HKD")
            precondition(StockRules.value(saved, on: due)?.vestedShares == 300_000)
            let savedProfile = try context.fetch(FetchDescriptor<UserProfile>())[0]
            precondition(savedProfile.stockMigrated)
            saved.priceCents = ProfileRules.maximumMoneyCents
            precondition(StockRules.value(saved, on: before) == nil)
            saved.vestingData = Data([0, 1])
            precondition(StockRules.value(saved, on: before) == nil)
        }
        print("Stock vesting boundaries, totals, FX, legacy deduplication, rollback and persistence passed")
    }
}
