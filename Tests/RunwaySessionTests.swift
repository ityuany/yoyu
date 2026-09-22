import Foundation

@main struct RunwaySessionTests {
    @MainActor static func main() async throws {
        let cache = RunwayCache()
        let f = try RunwayFixture("Session", years: 100, expenseCount: 24, loans: true)
        let key = f.plan.cacheKey
        for _ in 0..<100 { precondition(f.plan.cacheKey == key) }
        var changed = f.plan; changed.mode = .indefinite
        precondition(changed.cacheKey != key)
        let r = RunwayResult(origin: f.today, end: f.today)
        cache.store(r, for: key)
        precondition(cache.result(for: key) != nil && cache.result(for: changed.cacheKey) == nil)
        for index in 0..<3 { cache.store(r, for: "revision-\(index)") }
        precondition(cache.result(for: key) == nil)
        precondition(cache.result(for: "revision-2") != nil)
        let task = Task { await f.run(old: false) }
        try await Task.sleep(for: .milliseconds(10))
        task.cancel()
        let cancelled = await task.value
        precondition(cancelled.issue == "计算已取消")
        // Cancelling one calculation must not poison a later independent request.
        let short = try RunwayFixture("After cancellation", years: 1)
        let next = await short.run(old: false)
        precondition(next.issue == nil && next.failure == nil)
        print("Session tests passed: stable keys, revisions, bounded cache, cancellation and subsequent calculation.")
    }
}
