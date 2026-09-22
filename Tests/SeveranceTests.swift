import Foundation
import SwiftData

@main struct SeveranceTests {
    @MainActor static func main() throws {
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            ProfileRules.calendar.startOfDay(for: ProfileRules.date(year, month, day))
        }
        func tenure(_ start: Date?, _ end: Date) -> Int64? {
            SeveranceRules.tenureHundredths(start: start, on: end)
        }
        let start = date(2022, 3, 15)
        precondition(tenure(nil, date(2026, 9, 15)) == nil)
        precondition(tenure(start, date(2022, 3, 14)) == nil)
        precondition(tenure(start, start) == 50)
        precondition(tenure(start.addingTimeInterval(60 * 60 * 23), start) == 50)
        precondition(tenure(start, date(2022, 9, 14)) == 50)
        precondition(tenure(start, date(2022, 9, 15)) == 100)
        precondition(tenure(start, date(2023, 3, 14)) == 100)
        precondition(tenure(start, date(2023, 3, 15)) == 100)
        precondition(tenure(start, date(2023, 3, 16)) == 150)
        precondition(tenure(start, date(2026, 9, 14)) == 450)
        precondition(tenure(start, date(2026, 9, 15)) == 500)
        precondition(tenure(start, date(2026, 9, 15).addingTimeInterval(-1)) == 450)
        precondition(tenure(date(2024, 8, 31), date(2025, 2, 27)) == 50)
        precondition(tenure(date(2024, 8, 31), date(2025, 2, 28)) == 100)
        precondition(tenure(date(2024, 2, 29), date(2028, 2, 29)) == 400)
        precondition(tenure(date(1900, 1, 1), date(2000, 1, 1)) == 10_000)
        precondition(tenure(date(1900, 1, 1), date(2000, 1, 2)) == nil)
        precondition(tenure(date(1900, 1, 1), date(2100, 1, 1)) == nil)

        let job = Employment()
        job.start = start
        let today = date(2026, 9, 15)
        let salary: Int64 = 2_000_000
        let defaults = SeveranceSettings()
        precondition(defaults.plan == .nPlusOne)
        precondition(defaults.baseSalaryCents == nil && defaults.noticeSalaryCents == nil)
        precondition(defaults.tenureHundredths == nil && defaults.customAmountCents == nil)
        precondition(SeveranceRules.settings(for: job) == defaults)
        let normal = SeveranceRules.estimate(settings: defaults, job: job, salaryCents: salary, noticeSalaryCents: salary, on: today)!
        precondition(normal.amountCents == 12_000_000 && normal.tenureHundredths == 500)
        precondition(normal.baseSalaryCents == salary && normal.noticeSalaryCents == salary)

        let twoN = SeveranceRules.estimate(settings: SeveranceSettings(plan: .twoN), job: job, salaryCents: salary, noticeSalaryCents: salary, on: today)!
        precondition(twoN.amountCents == 20_000_000 && twoN.tenureHundredths == 500)
        precondition(twoN.baseSalaryCents == salary && twoN.noticeSalaryCents == nil)
        let savedTwoN = SeveranceSettings(plan: .twoN, baseSalaryCents: 1_500_000, noticeSalaryCents: 2_500_000, tenureHundredths: 425)
        let manualTwoN = SeveranceRules.estimate(settings: savedTwoN, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)!
        precondition(manualTwoN.amountCents == 12_750_000 && manualTwoN.noticeSalaryCents == nil)
        var doubled = savedTwoN
        doubled.noticeSalaryCents = .max
        precondition(SeveranceRules.estimate(settings: doubled, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == manualTwoN.amountCents)
        doubled.baseSalaryCents = 101
        doubled.tenureHundredths = 50
        precondition(SeveranceRules.estimate(settings: doubled, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == 101)
        doubled.tenureHundredths = 0
        precondition(SeveranceRules.estimate(settings: doubled, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == 0)
        doubled.baseSalaryCents = ProfileRules.maximumMoneyCents / 2
        doubled.tenureHundredths = 100
        precondition(SeveranceRules.estimate(settings: doubled, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == ProfileRules.maximumMoneyCents)
        doubled.baseSalaryCents = ProfileRules.maximumMoneyCents / 2 + 1
        precondition(SeveranceRules.estimate(settings: doubled, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today) == nil)
        doubled.baseSalaryCents = ProfileRules.maximumMoneyCents
        doubled.tenureHundredths = 50
        precondition(SeveranceRules.estimate(settings: doubled, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == ProfileRules.maximumMoneyCents)
        doubled.tenureHundredths = 10_000
        precondition(SeveranceRules.estimate(settings: doubled, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today) == nil)

        var adjusted = defaults
        adjusted.baseSalaryCents = 1_500_000
        adjusted.noticeSalaryCents = 2_500_000
        adjusted.tenureHundredths = 425
        let manual = SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)!
        precondition(manual.amountCents == 8_875_000)
        precondition(manual.tenureHundredths == 425 && manual.baseSalaryCents == 1_500_000 && manual.noticeSalaryCents == 2_500_000)
        adjusted.noticeSalaryCents = nil
        precondition(SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: salary, noticeSalaryCents: salary, on: today)?.amountCents == 8_375_000)
        precondition(SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today) == nil)
        adjusted.plan = .n
        let nOnly = SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)!
        precondition(nOnly.amountCents == 6_375_000 && nOnly.noticeSalaryCents == nil)
        adjusted.baseSalaryCents = 101
        adjusted.tenureHundredths = 50
        precondition(SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == 51)
        adjusted.tenureHundredths = 0
        precondition(SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == 0)
        adjusted.tenureHundredths = 10_000
        precondition(SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == 10_100)
        for invalid: Int64 in [-1, 10_001, .max] {
            adjusted.tenureHundredths = invalid
            precondition(SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: salary, noticeSalaryCents: salary, on: today) == nil)
        }
        adjusted.tenureHundredths = 100
        for invalid: Int64 in [-1, ProfileRules.maximumMoneyCents + 1, .max] {
            adjusted.baseSalaryCents = invalid
            precondition(SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: salary, noticeSalaryCents: salary, on: today) == nil)
            precondition(SeveranceRules.estimate(settings: defaults, job: job, salaryCents: invalid, noticeSalaryCents: invalid, on: today) == nil)
        }
        adjusted.baseSalaryCents = ProfileRules.maximumMoneyCents
        precondition(SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == ProfileRules.maximumMoneyCents)
        adjusted.plan = .nPlusOne
        adjusted.noticeSalaryCents = 1
        precondition(SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today) == nil)
        adjusted.noticeSalaryCents = .max
        adjusted.baseSalaryCents = 0
        precondition(SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: salary, noticeSalaryCents: salary, on: today) == nil)
        adjusted.noticeSalaryCents = 0
        adjusted.baseSalaryCents = ProfileRules.maximumMoneyCents
        adjusted.tenureHundredths = 10_000
        precondition(SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: salary, noticeSalaryCents: salary, on: today) == nil)

        precondition(SeveranceRules.estimate(settings: defaults, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today) == nil)
        job.start = nil
        precondition(SeveranceRules.estimate(settings: defaults, job: job, salaryCents: salary, noticeSalaryCents: salary, on: today) == nil)
        adjusted = SeveranceSettings(plan: .n, baseSalaryCents: salary, tenureHundredths: 250)
        precondition(SeveranceRules.estimate(settings: adjusted, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == 5_000_000)
        let custom = SeveranceSettings(plan: .customAmount, customAmountCents: 5_432_100)
        let customEstimate = SeveranceRules.estimate(settings: custom, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)!
        precondition(customEstimate.amountCents == 5_432_100)
        precondition(customEstimate.tenureHundredths == nil && customEstimate.baseSalaryCents == nil && customEstimate.noticeSalaryCents == nil)
        precondition(SeveranceRules.estimate(settings: SeveranceSettings(plan: .customAmount), job: job, salaryCents: salary, noticeSalaryCents: salary, on: today) == nil)
        for invalid: Int64 in [-1, ProfileRules.maximumMoneyCents + 1, .max] {
            let invalidCustom = SeveranceSettings(plan: .customAmount, customAmountCents: invalid)
            precondition(SeveranceRules.estimate(settings: invalidCustom, job: job, salaryCents: salary, noticeSalaryCents: salary, on: today) == nil)
        }
        let zeroCustom = SeveranceSettings(plan: .customAmount, customAmountCents: 0)
        precondition(SeveranceRules.estimate(settings: zeroCustom, job: job, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == 0)
        job.start = date(2027, 1, 1)
        precondition(SeveranceRules.estimate(settings: custom, job: job, salaryCents: salary, noticeSalaryCents: salary, on: today) == nil)
        job.start = start
        job.end = today
        precondition(SeveranceRules.estimate(settings: custom, job: job, salaryCents: salary, noticeSalaryCents: salary, on: today) == nil)
        job.end = nil

        precondition(SeveranceRules.wealth(currentCents: 20_000_000, compensationCents: normal.amountCents) == 32_000_000)
        precondition(SeveranceRules.wealth(currentCents: nil, compensationCents: normal.amountCents) == nil)
        precondition(SeveranceRules.wealth(currentCents: 20_000_000, compensationCents: nil) == nil)
        precondition(SeveranceRules.wealth(currentCents: 0, compensationCents: 0) == 0)
        precondition(SeveranceRules.wealth(currentCents: ProfileRules.maximumMoneyCents, compensationCents: 0) == ProfileRules.maximumMoneyCents)
        precondition(SeveranceRules.wealth(currentCents: ProfileRules.maximumMoneyCents, compensationCents: 1) == nil)
        precondition(SeveranceRules.wealth(currentCents: .max, compensationCents: .max) == nil)
        precondition(SeveranceRules.wealth(currentCents: -1, compensationCents: 1) == nil)
        precondition(SeveranceRules.wealth(currentCents: 1, compensationCents: -1) == nil)

        job.severanceData = Data([0, 1])
        precondition(SeveranceRules.settings(for: job) == nil)
        job.severanceData = Data(#"{"plan":"unknown"}"#.utf8)
        precondition(SeveranceRules.settings(for: job) == nil)
        job.severanceData = Data(#"{"plan":"nPlusOne"}"#.utf8)
        precondition(SeveranceRules.settings(for: job) == defaults)
        job.severanceData = try JSONEncoder().encode(savedTwoN)
        precondition(SeveranceRules.settings(for: job) == savedTwoN)
        job.severanceData = nil
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([Employment.self])
        let config = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("severance.store"), cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            context.insert(job)
            try context.save()
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let saved = try context.fetch(FetchDescriptor<Employment>())[0]
            precondition(saved.severanceData == nil && SeveranceRules.settings(for: saved) == defaults)
            precondition(SeveranceRules.estimate(settings: SeveranceRules.settings(for: saved)!, job: saved, salaryCents: salary, noticeSalaryCents: salary, on: today)?.amountCents == normal.amountCents)
            saved.severanceData = try JSONEncoder().encode(custom)
            try context.save()
            saved.severanceData = try JSONEncoder().encode(adjusted)
            context.rollback()
            precondition(SeveranceRules.settings(for: saved) == custom)
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let saved = try context.fetch(FetchDescriptor<Employment>())[0]
            precondition(SeveranceRules.settings(for: saved) == custom)
            precondition(SeveranceRules.estimate(settings: SeveranceRules.settings(for: saved)!, job: saved, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == customEstimate.amountCents)
            saved.severanceData = try JSONEncoder().encode(savedTwoN)
            try context.save()
            saved.severanceData = try JSONEncoder().encode(defaults)
            context.rollback()
            precondition(SeveranceRules.settings(for: saved) == savedTwoN)
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let saved = try context.fetch(FetchDescriptor<Employment>())[0]
            precondition(SeveranceRules.settings(for: saved) == savedTwoN)
            precondition(SeveranceRules.estimate(settings: SeveranceRules.settings(for: saved)!, job: saved, salaryCents: nil, noticeSalaryCents: nil, on: today)?.amountCents == manualTwoN.amountCents)
            saved.severanceData = Data([0, 1])
            try context.save()
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let saved = try context.fetch(FetchDescriptor<Employment>())[0]
            precondition(SeveranceRules.settings(for: saved) == nil)
        }
        let cappedJob = Employment()
        cappedJob.start = date(2009, 1, 1)
        let capDate = date(2026, 9, 21)
        let cap: Int64 = 3_000_000
        let cappedSettings = SeveranceSettings(plan: .nPlusOne, tripleAverageSalaryCents: cap)
        let capped = SeveranceRules.estimate(settings: cappedSettings, job: cappedJob, salaryCents: 4_000_000, noticeSalaryCents: 5_000_000, on: capDate)!
        precondition(capped.isDoubleCapped && capped.tenureHundredths == 1_200)
        precondition(capped.baseSalaryCents == cap && capped.amountCents == 41_000_000)
        for base in [cap - 1, cap] {
            let result = SeveranceRules.estimate(settings: cappedSettings, job: cappedJob, salaryCents: base, noticeSalaryCents: 0, on: capDate)!
            precondition(!result.isDoubleCapped && result.tenureHundredths == 1_800)
        }
        var twice = cappedSettings
        twice.plan = .twoN
        precondition(SeveranceRules.estimate(settings: twice, job: cappedJob, salaryCents: 4_000_000, on: capDate)?.amountCents == 72_000_000)
        precondition(SeveranceRules.estimate(settings: cappedSettings, job: cappedJob, salaryCents: 4_000_000, on: capDate) == nil)
        let roundTrip = try JSONDecoder().decode(SeveranceSettings.self, from: JSONEncoder().encode(cappedSettings))
        precondition(roundTrip == cappedSettings)
        cappedJob.start = date(2020, 1, 1)
        let shorter = SeveranceRules.estimate(settings: twice, job: cappedJob, salaryCents: 4_000_000, on: capDate)!
        precondition(shorter.isDoubleCapped && shorter.tenureHundredths == 700 && shorter.amountCents == 42_000_000)
        for invalidCap: Int64 in [0, -1, .max] {
            twice.tripleAverageSalaryCents = invalidCap
            precondition(SeveranceRules.estimate(settings: twice, job: cappedJob, salaryCents: 4_000_000, on: capDate) == nil)
        }
        let legacy = SeveranceSettings(plan: .customAmount, baseSalaryCents: 1, noticeSalaryCents: 2,
                                       tenureHundredths: 3, customAmountCents: 4, tripleAverageSalaryCents: cap)
        precondition(legacy.automatic == SeveranceSettings(tripleAverageSalaryCents: cap))
        precondition(legacy.automatic.automatic == legacy.automatic)
        precondition(savedTwoN.automatic.plan == .twoN)
        precondition(savedTwoN.automatic.baseSalaryCents == nil)
        precondition(SeveranceSettings(plan: .n).automatic.plan == .n)
        let incomeJob = Employment()
        incomeJob.start = date(2020, 1, 1)
        let early = SalaryStage()
        early.employmentID = incomeJob.id
        early.effectiveDate = incomeJob.start
        early.salaryCents = 2_000_000
        early.bonusCents = 12_000_000
        let later = SalaryStage()
        later.employmentID = incomeJob.id
        later.effectiveDate = date(2026, 3, 1)
        later.salaryCents = 4_000_000
        later.bonusCents = 24_000_000
        let incomeStages = [early, later]
        precondition(SeveranceRules.averageSalary(stages: incomeStages, job: incomeJob, on: capDate) == 4_500_000)
        precondition(SeveranceRules.previousMonthSalary(stages: incomeStages, job: incomeJob, on: capDate) == 4_000_000)
        precondition(SeveranceRules.averageSalary(stages: [later], job: incomeJob, on: capDate) == nil)
        incomeJob.start = date(2026, 8, 16)
        later.effectiveDate = incomeJob.start
        precondition(SeveranceRules.averageSalary(stages: [later], job: incomeJob, on: capDate) == 6_000_000)
        later.bonusCents = nil
        precondition(SeveranceRules.averageSalary(stages: [later], job: incomeJob, on: capDate) == 4_000_000)
        incomeJob.start = date(2026, 9, 1)
        precondition(SeveranceRules.averageSalary(stages: [later], job: incomeJob, on: capDate) == nil)
        print("Severance tenure boundaries, estimates, validation, wealth totals, rollback and persistence passed")
    }
}
