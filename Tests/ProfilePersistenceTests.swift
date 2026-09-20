import Foundation
import SwiftData

@main
struct ProfilePersistenceTests {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([UserProfile.self, WorkdayOverride.self])
        let configuration = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("test.store"), cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            let profile = UserProfile()
            profile.birthYear = 1995
            profile.birthMonth = 6
            profile.gender = "男"
            profile.cashCents = 10001
            profile.stockCents = 20002
            profile.basicUpdatedAt = Date()
            profile.wealthUpdatedAt = Date()
            precondition(profile.workweek == .default)
            profile.workweek.set(.saturday, isWorkday: true)
            precondition(profile.workweekMask == 126, "workweek must write through to stored mask")
            context.insert(profile)
            context.insert(WorkdayOverride(dateKey: "2026-09-20", isWorkday: false))
            try context.save()
            precondition(profile.retirement == "2058 年 6 月")
            precondition(profile.totalWealth == 30003)
            profile.gender = "女"
            context.rollback()
            precondition(profile.gender == "男")
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            let profiles = try context.fetch(FetchDescriptor<UserProfile>())
            precondition(profiles.count == 1)
            precondition(profiles[0].cashCents == 10001)
            precondition(profiles[0].investmentCents == nil)
            precondition(profiles[0].retirement == "2058 年 6 月")
            precondition(profiles[0].stockValueCents == 20002)
            precondition(profiles[0].stockSharesHundredths == nil)
            precondition(profiles[0].investmentAnnualReturnBasisPoints == nil)
            precondition(profiles[0].investmentRegistrationDate == nil)
            precondition(profiles[0].investmentInterestMode == "单利")
            precondition(profiles[0].workweekMask == 126)
            precondition(profiles[0].workweek.contains(.saturday) && !profiles[0].workweek.contains(.sunday))
            profiles[0].stockSharesHundredths = 10000
            profiles[0].stockPriceCents = 1234
            profiles[0].investmentAnnualReturnBasisPoints = -250
            profiles[0].investmentRegistrationDate = ProfileRules.date(2026, 9, 1)
            profiles[0].investmentInterestMode = "复利"
            precondition(profiles[0].stockValueCents == 123400)
            precondition(profiles[0].totalWealth == 133401)
            let overrides = try context.fetch(FetchDescriptor<WorkdayOverride>())
            precondition(overrides.count == 1 && !overrides[0].isWorkday)
            context.delete(overrides[0])
            try context.save()
            let count = try context.fetchCount(FetchDescriptor<WorkdayOverride>())
            precondition(count == 0)
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            let profiles = try context.fetch(FetchDescriptor<UserProfile>())
            let profile = profiles[0]
            precondition(profile.stockSharesHundredths == 10000)
            precondition(profile.stockPriceCents == 1234)
            precondition(profile.stockValueCents == 123400)
            precondition(profile.investmentAnnualReturnBasisPoints == -250)
            precondition(profile.investmentRegistrationDate == ProfileRules.date(2026, 9, 1))
            precondition(profile.investmentInterestMode == "复利")
            profile.stockPriceCents = 2468
            precondition(profile.stockValueCents == 246800)
            precondition(profile.totalWealth == 256801)
        }
        print("PASS: SwiftData disk save/reopen, legacy stock preservation, live stock valuation, signed annual return, retirement, rollback and override removal")
    }
}
