import Foundation

@main struct RunwayPerformanceTests {
    @MainActor static func main() async throws {
        let baselineOnly = CommandLine.arguments.contains("--baseline")
        let rounds = baselineOnly ? 1 : 5
        let fixtures = try [RunwayFixture("示例：不再就业至耗尽", years: 100, example: true), RunwayFixture("20年：1项支出", years: 20), RunwayFixture("100年：24项支出+2笔房贷", years: 100, expenseCount: 24, loans: true)]
        for f in fixtures {
            if !baselineOnly { _ = await f.run(old: true); _ = await f.run(old: false) }
            var oldTimes: [Double] = [], newTimes: [Double] = []
            for round in 0..<rounds {
                for old in (baselineOnly ? [true] : round % 2 == 0 ? [true,false] : [false,true]) {
                    let clock = ContinuousClock(); let start = clock.now
                    let r = await f.run(old: old)
                    let elapsed = start.duration(to: clock.now); let ms = Double(elapsed.components.seconds)*1000 + Double(elapsed.components.attoseconds)/1e15
                    precondition(r.issue == nil, r.issue ?? "")
                    if old { oldTimes.append(ms) } else { newTimes.append(ms) }
                    print("SAMPLE \(f.name) \(old ? "old" : "new") \(String(format:"%.3f", ms))ms \(r.duration)")
                }
            }
            if !baselineOnly {
                let a = await f.run(old: true), b = await f.run(old: false)
                precondition(signature(a) == signature(b), "Result mismatch: \(f.name)")
                let old = oldTimes.sorted()[rounds/2], new = newTimes.sorted()[rounds/2]
                print("RESULT \(f.name) old=\(String(format:"%.3f",old))ms new=\(String(format:"%.3f",new))ms speedup=\(String(format:"%.2f",old/new))x SAME")
            }
        }
    }
}
