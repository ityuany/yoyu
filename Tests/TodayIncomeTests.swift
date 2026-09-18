import Foundation
import SwiftData

@main struct TodayIncomeTests {
    static func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value + "+08:00")! }
    static func main() {
        let job = Employment()
        job.start = date("2026-06-01T00:00:00")
        job.followsHolidays = false
        let stage = SalaryStage()
        stage.employmentID = job.id
        stage.effectiveDate = job.start
        stage.salaryCents = 2_200_000 // June 2026: 22 weekdays, 1000 yuan/day.
        func snapshot(_ time: String, _ stages: [SalaryStage]? = nil) -> TodayIncome.Snapshot {
            TodayIncome.snapshot(job: job, stages: stages ?? [stage], now: date(time))!
        }
        let before = snapshot("2026-06-02T08:59:59")
        precondition(before.status == .beforeWork && before.earnedCents == 0 && before.dailyCents == 100_000)
        let start = snapshot("2026-06-02T09:00:00")
        precondition(start.status == .working && start.progress == 0)
        let second = snapshot("2026-06-02T09:00:01")
        precondition(second.earnedCents > start.earnedCents)
        let half = snapshot("2026-06-02T13:30:00")
        precondition(half.earnedCents == 50_000 && half.monthCents == 150_000)
        let finish = snapshot("2026-06-02T18:00:00")
        precondition(finish.status == .finished && finish.earnedCents == finish.dailyCents)
        precondition(snapshot("2026-06-02T23:59:59").earnedCents == finish.earnedCents)
        precondition(snapshot("2026-06-03T00:00:00").earnedCents == 0)
        precondition(snapshot("2026-06-06T12:00:00").status == .rest)
        precondition(snapshot("2026-06-06T12:00:00").earnedCents == 0)
        precondition(snapshot("2026-06-30T18:00:00").monthCents == stage.salaryCents)
        let raise = SalaryStage()
        raise.employmentID = job.id
        raise.effectiveDate = date("2026-06-02T00:00:00")
        raise.salaryCents = 4_400_000
        precondition(snapshot("2026-06-02T18:00:00", [stage, raise]).monthCents == 300_000)
        precondition(snapshot("2026-06-01T18:00:00", [stage, raise]).dailyCents == 100_000)
        precondition(TodayIncome.snapshot(job: job, stages: [raise], now: date("2026-06-02T18:00:00"))?.monthCents == nil)
        stage.effectiveDate = nil
        precondition(TodayIncome.snapshot(job: job, stages: [stage], now: date("2026-06-02T18:00:00")) == nil)
        stage.effectiveDate = job.start
        job.startMinutes = 22 * 60
        job.endMinutes = 6 * 60
        let overnight = snapshot("2026-06-03T02:00:00")
        precondition(overnight.day == date("2026-06-02T00:00:00") && overnight.progress == 0.5)
        precondition(overnight.earnedCents == 50_000)
        precondition(snapshot("2026-06-06T02:00:00").status == .working) // Friday shift continues on Saturday.
        job.startMinutes = job.endMinutes
        precondition(TodayIncome.snapshot(job: job, stages: [stage], now: date("2026-06-03T02:00:00")) == nil)
        job.startMinutes = 9 * 60
        job.endMinutes = 18 * 60
        job.start = date("2026-01-01T00:00:00")
        stage.effectiveDate = job.start
        job.followsHolidays = true
        precondition(snapshot("2026-01-01T12:00:00").status == .rest)
        precondition(snapshot("2026-01-04T12:00:00").status == .working)
        precondition(!snapshot("2026-01-04T12:00:00").missingHolidayYear)
        precondition(snapshot("2027-01-04T12:00:00").missingHolidayYear)
        precondition(TodayIncome.nextShift(job: job, stages: [stage], after: date("2026-01-03T12:00:00"))?.start == date("2026-01-04T09:00:00"))
        job.followsHolidays = false
        precondition(snapshot("2026-06-06T12:00:00").completedWorkdays == 5)
        precondition(TodayIncome.nextShift(job: job, stages: [stage], after: date("2026-06-06T12:00:00"))?.start == date("2026-06-08T09:00:00"))
        raise.effectiveDate = date("2026-07-01T00:00:00")
        let july = TodayIncome.nextShift(job: job, stages: [stage, raise], after: date("2026-06-30T20:00:00"))!
        precondition(july.start == date("2026-07-01T09:00:00") && july.dailyCents == 191_304)
        let nextYear = TodayIncome.nextShift(job: job, stages: [stage], after: date("2026-12-31T20:00:00"))!
        precondition(nextYear.start == date("2027-01-01T09:00:00"))
        job.end = date("2026-06-07T00:00:00")
        precondition(TodayIncome.nextShift(job: job, stages: [stage], after: date("2026-06-06T12:00:00")) == nil)
        job.end = nil
        job.workweekMask = 0
        job.followsHolidays = false
        precondition(snapshot("2026-06-02T12:00:00").monthlyWorkdays == 0)
        precondition(snapshot("2026-06-02T12:00:00").earnedCents == 0)
        precondition(TodayIncome.nextShift(job: job, stages: [stage], after: date("2026-06-06T12:00:00")) == nil)
        print("Today income: per-second accrual, boundaries, month total, raises, missing data, holidays and overnight shifts passed")
    }
}
