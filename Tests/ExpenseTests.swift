import Foundation
import SwiftData

@main struct ExpenseTests {
    @MainActor static func main() throws {
        let date = ProfileRules.date
        var plan = ExpensePlan(name: "生活费", amount: 3100_00, start: date(2026, 1, 16), end: date(2026, 2, 14))
        precondition(ExpenseRules.monthStatus(plan, in: date(2026, 1, 1)) == "当月有效")
        precondition(ExpenseRules.monthStatus(plan, in: date(2026, 3, 1)) == "已结束")
        precondition(ExpenseRules.monthStatus(plan, in: date(2025, 12, 1)) == "未开始")
        precondition(ExpenseRules.amount(plan, in: date(2026, 1, 1)) == 1600_00)
        precondition(ExpenseRules.amount(plan, in: date(2026, 2, 1)) == 1550_00)
        precondition(ExpenseRules.amount(plan, in: date(2026, 3, 1)) == 0)
        precondition(ExpenseRules.amount(plan, in: date(2025, 12, 1)) == 0)
        plan.start = date(2028, 2, 29); plan.end = date(2028, 2, 29); plan.amount = 2900_00
        precondition(ExpenseRules.amount(plan, in: date(2028, 2, 1)) == 100_00)
        precondition(ExpenseRules.status(plan, on: date(2028, 2, 29)) == "进行中")
        precondition(ExpenseRules.status(plan, on: date(2028, 3, 1)) == "已结束")
        plan = ExpensePlan(name: "订阅", amount: 98_00, estimated: false, start: date(2026, 1, 31), spreadAcrossMonth: false, dueDay: 31)
        precondition(ExpenseRules.amount(plan, in: date(2026, 2, 1)) == 98_00)
        plan.end = date(2026, 3, 30)
        precondition(ExpenseRules.amount(plan, in: date(2026, 3, 1)) == 0)
        plan.end = date(2026, 3, 31)
        precondition(ExpenseRules.amount(plan, in: date(2026, 3, 1)) == 98_00)
        plan.start = date(2026, 1, 16); plan.dueDay = 1
        precondition(ExpenseRules.amount(plan, in: date(2026, 1, 1)) == 0)
        plan.frequency = .quarterly; plan.end = nil
        precondition(ExpenseRules.amount(plan, in: date(2026, 2, 1)) == 0)
        precondition(ExpenseRules.amount(plan, in: date(2026, 4, 1)) == 98_00)
        plan.frequency = .yearly; plan.start = date(2024, 2, 29); plan.dueDay = 29
        precondition(ExpenseRules.amount(plan, in: date(2025, 2, 1)) == 98_00)
        precondition(ExpenseRules.amount(plan, in: date(2025, 3, 1)) == 0)
        plan.end = date(2024, 1, 1)
        precondition(ExpenseRules.error(plan) != nil)
        plan.end = nil; plan.amount = 0
        precondition(ExpenseRules.error(plan) != nil)
        plan.amount = 98_00
        precondition(ExpenseRules.error(plan) == nil)

        var dated = ExpensePlan(name: "年度保险", amount: 100_00, frequency: .yearly, start: date(2026, 9, 15), spreadAcrossMonth: false, dueDay: 15)
        precondition(ExpenseRules.paymentPreview(dated).map(ProfileRules.dateKey) == ["2026-09-15", "2027-09-15", "2028-09-15"])
        dated.frequency = .quarterly
        precondition(ExpenseRules.paymentPreview(dated).map(ProfileRules.dateKey) == ["2026-09-15", "2026-12-15", "2027-03-15"])
        dated.frequency = .monthly; dated.start = date(2026, 1, 31); dated.dueDay = 31
        precondition(ExpenseRules.paymentPreview(dated).map(ProfileRules.dateKey) == ["2026-01-31", "2026-02-28", "2026-03-31"])
        dated.frequency = .yearly; dated.start = date(2028, 2, 29); dated.dueDay = 29
        precondition(ExpenseRules.paymentPreview(dated).map(ProfileRules.dateKey) == ["2028-02-29", "2029-02-28", "2030-02-28"])
        dated.frequency = .quarterly; dated.start = date(2026, 9, 20); dated.dueDay = 15
        precondition(ProfileRules.dateKey(ExpenseRules.firstPaymentDate(dated)) == "2026-12-15")
        precondition(ExpenseRules.amount(dated, in: date(2026, 9, 1)) == 0)
        dated.end = date(2026, 12, 15)
        precondition(ExpenseRules.paymentPreview(dated).map(ProfileRules.dateKey) == ["2026-12-15"])
        dated.end = date(2026, 12, 14)
        precondition(ExpenseRules.paymentPreview(dated).isEmpty)

        // Legacy JSON has no pause key; it must remain readable and keep its amount.
        let legacy = try JSONEncoder().encode(plan)
        let legacyFields = try JSONSerialization.jsonObject(with: legacy) as! [String: Any]
        precondition(legacyFields["pausesDuringWorkBreak"] == nil)
        let legacyPlan = try JSONDecoder().decode(ExpensePlan.self, from: legacy)
        precondition(legacyPlan.pausesDuringWorkBreak == nil)
        var commute = ExpensePlan(name: "通勤", amount: 3100_00, start: date(2026, 1, 1))
        let breaks = [ExpenseWorkBreak(start: date(2026, 1, 11), end: date(2026, 1, 20)),
                      ExpenseWorkBreak(start: date(2026, 1, 15), end: date(2026, 1, 25))]
        precondition(ExpenseRules.amount(commute, in: date(2026, 1, 1), workBreaks: breaks) == 3100_00)
        commute.pausesDuringWorkBreak = true
        precondition(ExpenseRules.amount(commute, in: date(2026, 1, 1)) == 3100_00)
        precondition(ExpenseRules.amount(commute, in: date(2026, 1, 1), workBreaks: breaks) == 1600_00)
        precondition(ExpenseRules.amount(commute, in: date(2026, 2, 1), workBreaks: breaks) == 3100_00)
        let ongoing = [ExpenseWorkBreak(start: date(2026, 1, 1), end: nil)]
        precondition(ExpenseRules.amount(commute, in: date(2026, 2, 1), workBreaks: ongoing) == 0)
        commute.end = date(2026, 1, 28)
        precondition(ExpenseRules.amount(commute, in: date(2026, 1, 1), workBreaks: breaks) == 1300_00)
        precondition(ExpenseRules.amount(commute, in: date(2026, 2, 1), workBreaks: breaks) == 0)
        commute.end = nil; commute.spreadAcrossMonth = false; commute.dueDay = 20; commute.frequency = .quarterly
        precondition(ExpenseRules.amount(commute, in: date(2026, 1, 1), workBreaks: breaks) == 0)
        precondition(ExpenseRules.amount(commute, in: date(2026, 2, 1), workBreaks: breaks) == 0)
        precondition(ExpenseRules.amount(commute, in: date(2026, 4, 1), workBreaks: breaks) == 3100_00)
        commute.frequency = .yearly
        let oneDay = [ExpenseWorkBreak(start: date(2026, 1, 20), end: date(2026, 1, 20))]
        precondition(ExpenseRules.amount(commute, in: date(2026, 1, 1), workBreaks: oneDay) == 0)
        precondition(ExpenseRules.amount(commute, in: date(2027, 1, 1), workBreaks: oneDay) == 3100_00)
        commute.pausesDuringWorkBreak = false
        precondition(ExpenseRules.amount(commute, in: date(2026, 1, 1), workBreaks: oneDay) == 3100_00)
        commute.pausesDuringWorkBreak = true
        let roundTrip = try JSONDecoder().decode(ExpensePlan.self, from: JSONEncoder().encode(commute))
        precondition(roundTrip.pausesDuringWorkBreak == true)
        plan.pausesDuringWorkBreak = true

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([RecurringExpense.self])
        let configuration = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("test.store"), cloudKitDatabase: .none)
        var id = ""
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container); context.autosaveEnabled = false
            try ExpenseStore.save(plan, record: nil, context: context)
            let record = try context.fetch(FetchDescriptor<RecurringExpense>()).first!
            id = record.id
            var draft = record.plan!; draft.amount = 99_00
            precondition(record.plan!.amount == 98_00)
            try ExpenseStore.save(draft, record: record, context: context)
            precondition(record.plan!.amount == 99_00)
            record.planData = Data([0]); context.rollback()
            precondition(record.plan!.amount == 99_00)
            draft.amount = 0
            do { try ExpenseStore.save(draft, record: record, context: context); preconditionFailure("invalid saved") }
            catch { precondition(record.plan!.amount == 99_00) }
            let duplicate = RecurringExpense(); duplicate.id = id; duplicate.planData = record.planData
            context.insert(duplicate); try context.save()
            precondition(ExpenseRules.total([record, duplicate], in: date(2025, 2, 1)) == 99_00)
            duplicate.planData = Data([0]); duplicate.modifiedAt = Date().addingTimeInterval(1)
            precondition(ExpenseRules.total([record, duplicate], in: date(2025, 2, 1)) == nil)
            context.rollback()
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            let records = try context.fetch(FetchDescriptor<RecurringExpense>())
            precondition(records.count == 2 && records.allSatisfy { $0.plan?.amount == 99_00 && $0.plan?.pausesDuringWorkBreak == true })
            try ExpenseStore.delete(id: id, context: context)
            let count = try context.fetchCount(FetchDescriptor<RecurringExpense>())
            precondition(count == 0)
        }
        print("ExpenseTests passed: date bounds, proration, recurrence, validation, draft isolation, rollback, deduplication, persistence and deletion")
    }
}
