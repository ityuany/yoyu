import Foundation
import SwiftData

@main struct CareerTests {
    @MainActor static func main() throws {
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
            precondition(CareerRules.stageError(date: ProfileRules.date(2020, 1, 1), id: nil, job: job, stages: all) != nil)
            precondition(CareerRules.employmentError(start: ProfileRules.date(2025, 1, 1), end: nil, id: nil, others: jobs, stages: []) != nil)
            precondition(CareerRules.employmentError(start: ProfileRules.date(2020, 1, 1), end: ProfileRules.date(2021, 1, 1), id: nil, others: jobs, stages: []) == nil)
            precondition(CareerRules.employmentError(start: job.start!, end: ProfileRules.date(2025, 1, 1), id: job.id, others: jobs, stages: all) != nil)
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
