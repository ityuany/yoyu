import Foundation
import SwiftData

@main struct CareerTests {
    @MainActor static func main() throws {
        let calendar = ProfileRules.calendar
        for (year, month, configured, expected) in [
            (2026, 2, 31, 28), (2028, 2, 31, 29), (2100, 2, 31, 28),
            (2026, 4, 31, 30), (2026, 3, 31, 31), (2026, 12, 31, 31),
            (2026, 2, 29, 28), (2028, 2, 29, 29), (2026, 2, 30, 28),
            (2026, 2, 10, 10), (2026, 2, 1, 1)
        ] {
            let actual = CareerRules.salaryPaymentDate(day: configured, inMonth: ProfileRules.date(year, month, 15))
            precondition(actual == calendar.startOfDay(for: ProfileRules.date(year, month, expected)))
        }
        // 每个月使用原始配置 31 号计算，二月取月末不应将三月也改成 28 号。
        for (month, expected) in [(1, 31), (2, 28), (3, 31), (4, 30), (5, 31)] {
            let actual = CareerRules.salaryPaymentDate(day: 31, inMonth: ProfileRules.date(2026, month, 1))
            precondition(actual == calendar.startOfDay(for: ProfileRules.date(2026, month, expected)))
        }
        for invalid in [0, 32, -1] {
            precondition(CareerRules.salaryPaymentDate(day: invalid, inMonth: Date()) == nil)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([UserProfile.self, Employment.self, SalaryStage.self])
        let config = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("career.store"), cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let old = UserProfile()
            old.salaryCents = 4_000_000
            old.hireDate = ProfileRules.date(2022, 3, 1)
            old.pensionBasisPoints = 800
            old.bonusCents = 14_000_000
            old.workweekMask = 126
            context.insert(old)
            try context.save()
            try CareerRules.migrate(context: context, profiles: [old], jobs: [], stages: [])
            let jobs = try context.fetch(FetchDescriptor<Employment>())
            let stages = try context.fetch(FetchDescriptor<SalaryStage>())
            precondition(jobs.count == 1 && stages.count == 1)
            let job = jobs[0]
            precondition(job.salaryPaymentDay == 10)
            job.salaryPaymentDay = 15
            precondition(job.workweekMask == 126 && job.name.isEmpty)
            precondition(stages[0].salaryCents == old.salaryCents && stages[0].effectiveDate == nil)
            precondition(stages[0].bonusCents == old.bonusCents && old.careerMigrated)
            try CareerRules.migrate(context: context, profiles: [old], jobs: jobs, stages: stages)
            let count = try context.fetchCount(FetchDescriptor<Employment>())
            precondition(count == 1)
            precondition(job.followsHolidays)
            job.followsHolidays = false
            job.name = "测试企业"
            let first = stages[0]
            first.effectiveDate = ProfileRules.calendar.startOfDay(for: ProfileRules.date(2022, 3, 1))
            let raise = SalaryStage()
            raise.employmentID = job.id
            raise.salaryCents = 4_500_000
            raise.effectiveDate = ProfileRules.calendar.startOfDay(for: ProfileRules.date(2026, 10, 1))
            context.insert(raise)
            let all = [first, raise]
            precondition(CareerRules.salary(all, for: job, on: ProfileRules.date(2026, 9, 13))?.salaryCents == 4_000_000)
            precondition(CareerRules.salary(all, for: job, on: ProfileRules.date(2026, 10, 1))?.salaryCents == 4_500_000)
            precondition(CareerRules.stageError(date: raise.effectiveDate!, id: nil, job: job, stages: all) != nil)
            precondition(CareerRules.stageError(date: raise.effectiveDate!, id: raise.id, job: job, stages: all) == nil)
            let monthlyRaise = SalaryStage()
            monthlyRaise.employmentID = job.id
            monthlyRaise.effectiveDate = ProfileRules.date(2024, 2, 15)
            context.insert(monthlyRaise)
            precondition(CareerRules.stageError(date: ProfileRules.date(2024, 2, 25), id: nil, job: job, stages: [monthlyRaise]) != nil)
            try CareerRules.normalizeSalaryStageMonths(context: context)
            precondition(monthlyRaise.effectiveDate == calendar.startOfDay(for: ProfileRules.date(2024, 2, 1)))
            try CareerRules.normalizeSalaryStageMonths(context: context)
            context.delete(monthlyRaise)
            precondition(CareerRules.stageError(date: ProfileRules.date(2020, 1, 1), id: nil, job: job, stages: all) != nil)
            precondition(CareerRules.employmentError(start: ProfileRules.date(2025, 1, 1), end: nil, id: nil, others: jobs, stages: []) != nil)
            precondition(CareerRules.employmentError(start: ProfileRules.date(2020, 1, 1), end: ProfileRules.date(2021, 1, 1), id: nil, others: jobs, stages: []) == nil)
            precondition(CareerRules.employmentError(start: job.start!, end: ProfileRules.date(2025, 1, 1), id: job.id, others: jobs, stages: all) != nil)
            precondition(CareerRules.monthStart(ProfileRules.date(2024, 2, 16)) == calendar.startOfDay(for: ProfileRules.date(2024, 2, 1)))
            precondition(CareerRules.monthEnd(ProfileRules.date(2024, 2, 16)) == calendar.startOfDay(for: ProfileRules.date(2024, 2, 29)))
            let previous = Employment()
            previous.name = "前一家公司"
            previous.start = ProfileRules.date(2023, 1, 16)
            previous.end = ProfileRules.date(2024, 2, 3)
            context.insert(previous)
            precondition(CareerRules.employmentError(start: ProfileRules.date(2024, 2, 28), end: nil, id: nil, others: [previous], stages: []) != nil)
            precondition(CareerRules.employmentError(start: ProfileRules.date(2024, 3, 1), end: nil, id: nil, others: [previous], stages: []) == nil)
            try CareerRules.normalizeEmploymentMonths(context: context)
            precondition(previous.start == calendar.startOfDay(for: ProfileRules.date(2023, 1, 1)))
            precondition(previous.end == calendar.startOfDay(for: ProfileRules.date(2024, 2, 29)))
            try CareerRules.normalizeEmploymentMonths(context: context)
            context.delete(previous)
            let duplicate = Employment()
            duplicate.id = job.id
            duplicate.modifiedAt = job.modifiedAt.addingTimeInterval(-1)
            precondition(CareerRules.employments([job, duplicate]).count == 1)
            let other = Employment()
            precondition(CareerRules.current([job, other]) == nil)
            try context.save()
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let jobs = try context.fetch(FetchDescriptor<Employment>())
            let stages = try context.fetch(FetchDescriptor<SalaryStage>())
            precondition(jobs.count == 1 && stages.count == 2 && jobs[0].name == "测试企业")
            precondition(jobs[0].salaryPaymentDay == 15)
            jobs[0].salaryPaymentDay = 20
            context.rollback()
            precondition(jobs[0].salaryPaymentDay == 15)
            precondition(!jobs[0].followsHolidays)
            precondition(stages.allSatisfy { $0.employmentID == jobs[0].id })
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let job = try context.fetch(FetchDescriptor<Employment>())[0]
            let stages = try context.fetch(FetchDescriptor<SalaryStage>())
            let target = stages.first { $0.salaryCents == 4_500_000 }!
            let targetID = target.id
            let duplicate = SalaryStage()
            duplicate.id = targetID; duplicate.employmentID = job.id
            context.insert(duplicate)
            let other = Employment(); context.insert(other)
            let otherStage = SalaryStage()
            otherStage.id = targetID; otherStage.employmentID = other.id
            context.insert(otherStage)
            try context.save()
            try CareerRules.deleteStage(id: targetID, employmentID: job.id, context: context)
            let remaining = try context.fetch(FetchDescriptor<SalaryStage>())
            precondition(remaining.count == 2)
            precondition(remaining.contains { $0.employmentID == other.id })
            precondition(CareerRules.salary(remaining, for: job, on: ProfileRules.date(2026, 11, 1))?.salaryCents == 4_000_000)
            let last = remaining.first { $0.employmentID == job.id }!
            try CareerRules.deleteStage(id: last.id, employmentID: job.id, context: context)
            let after = try context.fetch(FetchDescriptor<SalaryStage>())
            precondition(CareerRules.salary(after, for: job) == nil)
            precondition((try? context.fetchCount(FetchDescriptor<Employment>())) == 2)
            let reopened = ModelContext(container)
            precondition((try? reopened.fetchCount(FetchDescriptor<SalaryStage>())) == 1)
        }
        let summaryJob = Employment()
        summaryJob.start = ProfileRules.date(2024, 2, 1)
        summaryJob.end = ProfileRules.date(2024, 2, 29)
        let base = SalaryStage()
        base.employmentID = summaryJob.id
        base.effectiveDate = summaryJob.start
        base.salaryCents = 290_000
        let cutoff = ProfileRules.date(2024, 3, 10)
        precondition(CareerRules.tenureDays(for: summaryJob, on: cutoff) == 29)
        precondition(CareerRules.estimatedSalaryCents([base], for: summaryJob, on: cutoff) == 290_000)
        let increase = SalaryStage()
        increase.employmentID = summaryJob.id
        increase.effectiveDate = ProfileRules.date(2024, 2, 15)
        increase.salaryCents = 580_000
        precondition(CareerRules.estimatedSalaryCents([base, increase], for: summaryJob, on: cutoff) == 440_000)
        precondition(CareerRules.estimatedSalaryCents([base, increase], for: summaryJob, on: ProfileRules.date(2024, 2, 14)) == 140_000)
        precondition(CareerRules.estimatedSalaryCents([increase], for: summaryJob, on: cutoff) == nil)
        increase.salaryCents = nil
        precondition(CareerRules.estimatedSalaryCents([base, increase], for: summaryJob, on: cutoff) == nil)
        increase.salaryCents = 580_000
        increase.effectiveDate = base.effectiveDate
        precondition(CareerRules.estimatedSalaryCents([base, increase], for: summaryJob, on: cutoff) == nil)
        base.effectiveDate = nil
        precondition(CareerRules.estimatedSalaryCents([base], for: summaryJob, on: cutoff) == nil)
        base.effectiveDate = ProfileRules.date(2024, 2, 29)
        summaryJob.start = summaryJob.end
        precondition(CareerRules.tenureDays(for: summaryJob, on: cutoff) == 1)
        precondition(CareerRules.estimatedSalaryCents([base], for: summaryJob, on: cutoff) == 10_000)
        summaryJob.end = nil
        precondition(CareerRules.tenureDays(for: summaryJob, on: ProfileRules.date(2024, 3, 1)) == 2)
        precondition(CareerRules.estimatedSalaryCents([base], for: summaryJob, on: ProfileRules.date(2024, 3, 1)) == 19_355)
        summaryJob.start = nil
        precondition(CareerRules.tenureDays(for: summaryJob, on: cutoff) == nil)
        precondition(CareerRules.estimatedSalaryCents([base], for: summaryJob, on: cutoff) == nil)
        let holidayJob = Employment()
        precondition(holidayJob.followsHolidays)
        holidayJob.start = ProfileRules.date(2026, 1, 1)
        holidayJob.end = ProfileRules.date(2026, 1, 4)
        let holidaySalary = SalaryStage()
        holidaySalary.employmentID = holidayJob.id
        holidaySalary.effectiveDate = holidayJob.start
        holidaySalary.salaryCents = 310_000
        let holidayCutoff = ProfileRules.date(2026, 1, 10)
        let officialSummary = CareerRules.workSummary([holidaySalary], for: holidayJob, on: holidayCutoff)!
        precondition(officialSummary.days == 1 && officialSummary.averageDailyCents == 40_000)
        precondition(!officialSummary.missingHolidayYears)
        holidayJob.followsHolidays = false
        precondition(CareerRules.workSummary([holidaySalary], for: holidayJob, on: holidayCutoff)?.days == 2)
        precondition(CareerRules.workSummary([holidaySalary], for: holidayJob, on: holidayCutoff)?.averageDailyCents == 20_000)
        holidayJob.followsHolidays = true
        holidayJob.end = ProfileRules.date(2026, 1, 3)
        precondition(CareerRules.workSummary([holidaySalary], for: holidayJob, on: holidayCutoff)?.days == 0)
        precondition(CareerRules.workSummary([holidaySalary], for: holidayJob, on: holidayCutoff)?.averageDailyCents == nil)
        holidayJob.start = ProfileRules.date(2025, 12, 31)
        precondition(CareerRules.workSummary([], for: holidayJob, on: holidayCutoff)?.missingHolidayYears == true)
        precondition(CareerRules.workSummary([], for: holidayJob, on: holidayCutoff)?.averageDailyCents == nil)
        holidayJob.followsHolidays = false
        precondition(CareerRules.workSummary([], for: holidayJob, on: holidayCutoff)?.missingHolidayYears == false)
        func retirement(_ year: Int, _ month: Int, _ gender: String, _ age: Int? = nil) -> String {
            ProfileRules.statutoryRetirement(year: year, month: month, gender: gender, femaleAge: age)
        }
        precondition(retirement(1964, 12, "男") == "2024 年 12 月")
        precondition(retirement(1965, 1, "男") == "2025 年 2 月")
        precondition(retirement(1965, 5, "男") == "2025 年 7 月")
        precondition(retirement(1967, 9, "男") == "2028 年 6 月")
        precondition(retirement(1991, 5, "男") == "2054 年 5 月")
        precondition(retirement(1970, 1, "女", 55) == "2025 年 2 月")
        precondition(retirement(1975, 3, "女", 50) == "2025 年 5 月")
        precondition(retirement(1991, 5, "女", 50) == "2046 年 5 月")
        precondition(retirement(1991, 5, "女", 55) == "2049 年 5 月")
        precondition(retirement(1991, 5, "女") == "请选择退休类别")
        print("Career migration, persistence, date boundaries, validation and retirement tests passed")
    }
}
