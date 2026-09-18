import Foundation

@main struct CareerReviewTests {
    static func main() {
        func job(_ start: Int, _ end: Int?) -> Employment {
            let j = Employment(); j.start = ProfileRules.date(2026, 1, start)
            j.end = end.map { ProfileRules.date(2026, 1, $0) }; return j
        }
        func stage(_ j: Employment, _ day: Int, _ cents: Int64?) -> SalaryStage {
            let s = SalaryStage(); s.employmentID = j.id; s.effectiveDate = ProfileRules.date(2026, 1, day); s.salaryCents = cents; return s
        }
        let a = job(1, 10), b = job(8, 20), c = job(25, nil)
        let base = stage(a, 1, 10000), raise = stage(a, 5, 20000)
        let missing = stage(b, 8, nil), future = stage(c, 31, 30000)
        let now = ProfileRules.date(2026, 1, 30)
        let summary = CareerReview.summary(jobs: [a,b,c], stages: [base,raise,missing,future], now: now)
        precondition(summary.totalDays == 26)
        precondition(summary.pay.count == 2 && summary.pay[1].previousCents == 10000)
        precondition(summary.incompleteJobs == 2)
        let conflict = stage(a, 5, 40000)
        let conflicting = CareerReview.summary(jobs: [a], stages: [base,raise,conflict], now: now)
        precondition(conflicting.pay.count == 1 && conflicting.incompleteJobs == 1)
        let duplicate = stage(a, 5, 20000); duplicate.id = raise.id
        let deduped = CareerReview.summary(jobs: [a], stages: [base,raise,duplicate], now: now)
        precondition(deduped.pay.count == 2)
        let gap = stage(a, 3, nil), recovery = stage(a, 7, 0)
        let gaps = CareerReview.summary(jobs: [a], stages: [base,gap,recovery], now: now)
        precondition(gaps.pay.count == 2 && gaps.pay[1].previousCents == nil && gaps.pay[1].cents == 0)
        let unknown = Employment()
        precondition(CareerReview.summary(jobs: [unknown], stages: [], now: now).incompleteJobs == 1)
        precondition(CareerReview.summary(jobs: [], stages: [], now: now).totalDays == 0)
        func pay(_ start: Date, _ end: Date, _ cents: Int64) -> CareerReview.Pay {
            .init(id: UUID().uuidString, jobID: "test", name: "Test", start: start, end: end, cents: cents, previousCents: nil)
        }
        func growth(_ pay: [CareerReview.Pay]) -> Double? {
            CareerReview.Summary(tenures: [], pay: pay, totalDays: 0, incompleteJobs: 0).annualizedSalaryGrowth
        }
        let start = ProfileRules.date(2020, 1, 1)
        let middle = ProfileRules.date(2021, 1, 1)
        let end = ProfileRules.date(2022, 1, 2)
        let initial = pay(start, middle, 10000)
        let terminal = pay(middle, end, 12100)
        precondition(abs(growth([initial, terminal])! - 0.1) < 0.001)
        precondition(abs(growth([pay(start, end, 10000)])!) < 0.000001)
        precondition(growth([initial, pay(middle, end, 8000)])! < 0)
        precondition(growth([initial, pay(middle, end, 0)])! == -1)
        precondition(growth([pay(start, middle, 0), terminal]) == nil)
        precondition(growth([pay(start, ProfileRules.date(2020, 6, 1), 10000)]) == nil)
        precondition(growth([]) == nil)
        precondition(growth([initial, initial, terminal]) == nil)
        precondition(growth([initial, terminal, terminal]) == nil)
        // Calendar gaps count toward elapsed years; they are not removed like tenure days.
        let gapInitial = pay(start, ProfileRules.date(2020, 2, 1), 10000)
        let gapTerminal = pay(ProfileRules.date(2021, 12, 1), end, 12100)
        precondition(abs(growth([gapInitial, gapTerminal])! - growth([initial, terminal])!) < 0.000001)
        print("Career review interval union, salary gaps, conflicts, duplicates and future date tests passed")
    }
}
