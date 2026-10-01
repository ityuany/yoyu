import Foundation

@MainActor private final class PendingCalculations {
    var continuations: [String: CheckedContinuation<RunwayResult, Never>] = [:]

    func calculate(_ input: RunwayInput) async -> RunwayResult {
        await withCheckedContinuation { continuations[input.revision] = $0 }
    }

    func waitFor(_ revision: String) async {
        for _ in 0..<1_000 {
            if continuations[revision] != nil { return }
            await Task.yield()
        }
        preconditionFailure("Calculation did not start")
    }

    func finish(_ input: RunwayInput) {
        let continuation = continuations.removeValue(forKey: input.revision)!
        continuation.resume(returning: RunwayResult(origin: input.today, end: input.today))
    }
}

@main struct RunwaySessionTests {
    @MainActor static func main() async throws {
        let today = ProfileRules.date(2026, 9, 22)
        func input(_ mode: RunwayMode, flexible: Int64 = 0) -> RunwayInput {
            var plan = RunwayPlan(mode: mode)
            plan.flexible = flexible
            return RunwayInput(plan: plan, profile: nil, stocks: [],
                jobs: [], stages: [], bonuses: [], expenses: [], liabilities: [], today: today)
        }
        let employed = input(.employed)
        let temporary = input(.temporary)
        let indefinite = input(.indefinite)
        precondition(employed.revision == input(.employed).revision)
        precondition(employed.revision != temporary.revision)
        let profile = UserProfile()
        profile.cashCents = 10_000_00
        let beforeCashChange = RunwayInput(plan: employed.plan, profile: profile, stocks: [],
            jobs: [], stages: [], bonuses: [], expenses: [], liabilities: [], today: today)
        profile.cashCents = 5_000_00
        let afterCashChange = RunwayInput(plan: employed.plan, profile: profile, stocks: [],
            jobs: [], stages: [], bonuses: [], expenses: [], liabilities: [], today: today)
        precondition(beforeCashChange.revision != afterCashChange.revision)

        let pending = PendingCalculations()
        let session = RunwaySession(calculate: { await pending.calculate($0) })
        let oldTask = Task { await session.run(employed) }
        await pending.waitFor(employed.revision)
        precondition(session.calculating(for: employed.revision))
        let newTask = Task { await session.run(temporary) }
        await pending.waitFor(temporary.revision)
        precondition(session.result(for: employed.revision) == nil)
        precondition(session.result(for: temporary.revision) == nil)
        pending.finish(employed)
        await oldTask.value
        precondition(session.result(for: employed.revision) == nil)
        precondition(session.calculating(for: temporary.revision))
        pending.finish(temporary)
        await newTask.value
        precondition(session.result(for: temporary.revision) != nil)
        precondition(!session.calculating(for: temporary.revision))

        // An exact input match displays its cached result without calculating.
        await session.run(temporary)
        precondition(session.result(for: temporary.revision) != nil)
        precondition(pending.continuations.isEmpty)

        // A different revision hides the previous result until it completes.
        let thirdTask = Task { await session.run(indefinite) }
        await pending.waitFor(indefinite.revision)
        precondition(session.result(for: temporary.revision) == nil)
        precondition(session.result(for: indefinite.revision) == nil)
        pending.finish(indefinite)
        await thirdTask.value

        var calculations = 0
        let bounded = RunwaySession(calculate: { input in
            calculations += 1
            return RunwayResult(origin: input.today, end: input.today)
        })
        let fourth = input(.employed, flexible: 1)
        for item in [employed, temporary, indefinite, fourth] { await bounded.run(item) }
        precondition(calculations == 4)
        await bounded.run(temporary)
        precondition(calculations == 4)
        await bounded.run(employed)
        precondition(calculations == 5)

        // 子关联到达或发生变化，即使父记录时间戳未变，也必须失效旧缓存。
        let childHolding = StockHolding()
        let grant = EquityGrant(name: "授予", date: ProfileRules.date(2026, 1, 1), shares: 100)
        childHolding.applyGrants([grant]); childHolding.applyDisposals([])
        func childInput() -> RunwayInput {
            RunwayInput(plan: RunwayPlan(), profile: nil, stocks: [childHolding], jobs: [],
                stages: [], bonuses: [], expenses: [], liabilities: [], today: ProfileRules.date(2026, 9, 22))
        }
        let beforeChildChange = childInput().revision
        let originalTimestamp = childHolding.modifiedAt
        childHolding.grantRecords!.first!.shares = 200
        precondition(childHolding.modifiedAt == originalTimestamp)
        precondition(childInput().revision != beforeChildChange)
        let completeRevision = childInput().revision
        childHolding.grantCount = 2
        precondition(childInput().revision != completeRevision)

        let f = try RunwayFixture("Session", years: 100, expenseCount: 24, loans: true)
        let task = Task { await f.run(old: false) }
        try await Task.sleep(for: .milliseconds(10))
        task.cancel()
        let cancelled = await task.value
        precondition(cancelled.issue == "计算已取消")
        let short = try RunwayFixture("After cancellation", years: 1)
        let next = await short.run(old: false)
        precondition(next.issue == nil && next.failure == nil)
        print("Session tests passed: revision matching, hidden stale results, late completion, bounded cache and cancellation.")
    }
}
