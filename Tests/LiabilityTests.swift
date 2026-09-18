import Foundation
import SwiftData

@main struct LiabilityTests {
    @MainActor static func main() throws {
        let baseline = ProfileRules.date(2026, 1, 1)
        let next = ProfileRules.date(2026, 1, 31)
        let annuity = MortgagePart(principal: 100000_00, annualPercent: 4.8, months: 12, nextDate: next, dueDay: 31)
        let rows = LiabilityRules.mortgage(annuity)
        precondition(rows.count == 12 && rows.last?.remaining == 0)
        precondition(rows.reduce(0) { $0 + $1.principal } == annuity.principal)
        precondition(rows[0].total == 855159 && rows[0].interest == 40000)
        precondition(ProfileRules.dateKey(rows[1].date) == "2026-02-28")
        precondition(ProfileRules.dateKey(rows[2].date) == "2026-03-31")
        let equal = MortgagePart(principal: 120000_00, annualPercent: 6, months: 12, method: .equalPrincipal, nextDate: next, dueDay: 31)
        let e = LiabilityRules.mortgage(equal)
        precondition(e.first!.total == 1060000 && e.last!.total == 1005000)
        precondition(e.allSatisfy { $0.principal == 1000000 })
        let zero = MortgagePart(principal: 100, annualPercent: 0, months: 3, nextDate: next, dueDay: 31)
        precondition(LiabilityRules.mortgage(zero).map(\.principal) == [33,33,34])
        let tiny = MortgagePart(principal: 100000_00, annualPercent: 1e-20, months: 12, nextDate: next, dueDay: 31)
        precondition(LiabilityRules.mortgage(tiny).last!.remaining == 0)
        let fixedPlan = CardInstallment(name: "手机", principal: 12000_00, months: 12, nextDate: next, dueDay: 31, terms: .init())
        var fixedCard = LiabilitySnapshot(installments: [fixedPlan], fixedInstallmentsOnly: true)
        precondition(LiabilityRules.error(fixedCard, kind: .creditCard) == nil)
        precondition(LiabilityRules.payments(fixedCard, kind: .creditCard).allSatisfy { $0.total == 1000_00 })
        fixedCard.installments[0].terms!.paid = 3
        precondition(LiabilityRules.balance(fixedCard, kind: .creditCard) == 9000_00)
        precondition(LiabilityRules.payments(fixedCard, kind: .creditCard).count == 9)
        precondition(LiabilityRules.confirmed(fixedCard, kind: .creditCard, on: next) == nil)
        let confirmedFixed = LiabilityRules.confirmed(fixedCard, kind: .creditCard, on: ProfileRules.date(2026, 5, 1))!
        precondition(confirmedFixed.installments[0].terms!.paid == 4)
        precondition(LiabilityRules.balance(confirmedFixed, kind: .creditCard) == 8000_00)
        fixedCard.installments[0].terms = .init(rate: 0.25, mode: .monthlyFee, paid: 0)
        precondition(LiabilityRules.payments(fixedCard, kind: .creditCard).allSatisfy { $0.total == 1030_00 })
        fixedCard.installments[0].principal = 100000_00
        fixedCard.installments[0].terms = .init(rate: 4.8)
        precondition(LiabilityRules.payments(fixedCard, kind: .creditCard).first!.total == 855159)
        fixedCard.installments[0].terms!.paid = 12
        precondition(LiabilityRules.balance(fixedCard, kind: .creditCard) == 0)
        precondition(LiabilityRules.payments(fixedCard, kind: .creditCard).isEmpty)
        fixedCard.installments[0].terms!.paid = 13
        precondition(LiabilityRules.error(fixedCard, kind: .creditCard) != nil)
        fixedCard.installments[0].terms = .init(rate: .nan)
        precondition(LiabilityRules.error(fixedCard, kind: .creditCard) != nil)
        let roundTrip = try JSONDecoder().decode(LiabilitySnapshot.self, from: JSONEncoder().encode(confirmedFixed))
        precondition(roundTrip.installments[0].terms!.paid == 4 && roundTrip.fixedInstallmentsOnly == true)
        let nextInput = ProfileRules.date(2026, 10, 10)
        let periodFive = LiabilityRules.fromNextInstallment(
            CardInstallment(name: "手机", principal: 12000_00, months: 12, terms: .init(automatic: true)),
            period: 5, nextPayment: nextInput, day: 10)!
        precondition(LiabilityRules.paidCount(periodFive, on: ProfileRules.date(2026, 9, 18)) == 4)
        let enteredRows = LiabilityRules.installments(periodFive, on: ProfileRules.date(2026, 9, 18))
        precondition(enteredRows.count == 8 && enteredRows.reduce(0) { $0 + $1.principal } == 8000_00)
        precondition(ProfileRules.dateKey(enteredRows.first!.date) == "2026-10-10")
        precondition(LiabilityRules.paidCount(periodFive, on: ProfileRules.date(2026, 10, 10)) == 4)
        precondition(LiabilityRules.paidCount(periodFive, on: ProfileRules.date(2026, 10, 11)) == 5)
        precondition(LiabilityRules.fromNextInstallment(periodFive, period: 0, nextPayment: nextInput, day: 10) == nil)
        precondition(LiabilityRules.fromNextInstallment(periodFive, period: 13, nextPayment: nextInput, day: 10) == nil)
        precondition(ProfileRules.dateKey(LiabilityRules.nextRepaymentDate(on: ProfileRules.date(2026, 9, 18), day: 10)) == "2026-10-10")
        precondition(ProfileRules.dateKey(LiabilityRules.nextRepaymentDate(on: ProfileRules.date(2026, 9, 10), day: 10)) == "2026-09-10")
        let febAnchor = LiabilityRules.fromNextInstallment(periodFive, period: 5, nextPayment: ProfileRules.date(2028, 2, 29), day: 31)!
        let febRows = LiabilityRules.installments(febAnchor, on: ProfileRules.date(2028, 2, 1))
        precondition(ProfileRules.dateKey(febRows[0].date) == "2028-02-29" && ProfileRules.dateKey(febRows[1].date) == "2028-03-31")
        // Automatic progress uses the calendar, not registration time or a saved paid count.
        var automaticPlan = CardInstallment(name: "自动分期", principal: 12000_00, months: 12,
                                            nextDate: next, dueDay: 31, terms: .init(automatic: true))
        let beforeStart = ProfileRules.date(2025, 12, 1)
        precondition(LiabilityRules.paidCount(automaticPlan, on: beforeStart) == 0)
        precondition(LiabilityRules.paidCount(automaticPlan, on: next) == 0)
        precondition(LiabilityRules.paidCount(automaticPlan, on: ProfileRules.date(2026, 2, 1)) == 1)
        precondition(LiabilityRules.paidCount(automaticPlan, on: ProfileRules.date(2026, 2, 28)) == 1)
        precondition(LiabilityRules.paidCount(automaticPlan, on: ProfileRules.date(2026, 3, 1)) == 2)
        precondition(ProfileRules.dateKey(LiabilityRules.installments(automaticPlan, on: ProfileRules.date(2026, 3, 1)).first!.date) == "2026-03-31")
        precondition(LiabilityRules.paidCount(automaticPlan, on: ProfileRules.date(2028, 1, 1)) == 12)
        automaticPlan.nextDate = ProfileRules.date(2024, 1, 31)
        precondition(LiabilityRules.paidCount(automaticPlan, on: ProfileRules.date(2024, 2, 29)) == 1)
        precondition(LiabilityRules.paidCount(automaticPlan, on: ProfileRules.date(2024, 3, 1)) == 2)
        automaticPlan.nextDate = next
        automaticPlan.terms!.rate = 0.25
        automaticPlan.terms!.mode = .monthlyFee
        let autoSnapshot = LiabilitySnapshot(installments: [automaticPlan], fixedInstallmentsOnly: true, cardRepaymentDay: 31)
        let march = ProfileRules.date(2026, 3, 1)
        precondition(LiabilityRules.balance(autoSnapshot, kind: .creditCard, on: march) == 10000_00)
        precondition(LiabilityRules.sum(LiabilityRules.payments(autoSnapshot, kind: .creditCard, on: march).map(\.total)) == 10300_00)
        precondition(LiabilityRules.confirmed(autoSnapshot, kind: .creditCard, on: march) == nil)
        automaticPlan.terms!.automatic = false
        automaticPlan.terms!.paid = 1
        let manualSnapshot = LiabilitySnapshot(installments: [automaticPlan], fixedInstallmentsOnly: true, cardRepaymentDay: 31)
        precondition(LiabilityRules.balance(manualSnapshot, kind: .creditCard, on: ProfileRules.date(2028, 1, 1)) == 11000_00)
        precondition(LiabilityRules.confirmed(manualSnapshot, kind: .creditCard, on: march)!.installments[0].terms!.paid == 2)
        let autoData = try JSONEncoder().encode(autoSnapshot)
        let restoredAuto = try JSONDecoder().decode(LiabilitySnapshot.self, from: autoData)
        precondition(restoredAuto.cardRepaymentDay == 31 && restoredAuto.installments[0].terms!.automatic == true)
        var legacyJSON = try JSONSerialization.jsonObject(with: autoData) as! [String: Any]
        legacyJSON.removeValue(forKey: "cardRepaymentDay")
        var legacyPlans = legacyJSON["installments"] as! [[String: Any]]
        var legacyTerms = legacyPlans[0]["terms"] as! [String: Any]
        legacyTerms.removeValue(forKey: "automatic")
        legacyTerms["paid"] = 3
        legacyPlans[0]["terms"] = legacyTerms
        legacyJSON["installments"] = legacyPlans
        let restoredLegacy = try JSONDecoder().decode(LiabilitySnapshot.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
        precondition(restoredLegacy.cardRepaymentDay == nil)
        precondition(LiabilityRules.paidCount(restoredLegacy.installments[0], on: march) == 3)
        // History is evaluated at the revision's date and does not drift as today changes.
        precondition(LiabilityRules.balance(autoSnapshot, kind: .creditCard, on: next) == 12000_00)
        var wrongDay = autoSnapshot
        wrongDay.cardRepaymentDay = 10
        precondition(LiabilityRules.error(wrongDay, kind: .creditCard) != nil)
        let snapshot = LiabilitySnapshot(balanceDate: baseline, mortgages: [annuity, equal])
        precondition(LiabilityRules.error(snapshot, kind: .mortgage) == nil)
        precondition(LiabilityRules.balance(snapshot, kind: .mortgage) == 220000_00)
        precondition(LiabilityRules.confirmed(snapshot, kind: .mortgage, on: baseline) == nil)
        let confirmed = LiabilityRules.confirmed(snapshot, kind: .mortgage, on: next)!
        precondition(confirmed.mortgages[0].principal == annuity.principal - rows[0].principal)
        precondition(confirmed.mortgages[1].principal == equal.principal - e[0].principal)
        precondition(confirmed.mortgages.allSatisfy { $0.months == 11 })
        precondition(ProfileRules.dateKey(LiabilityRules.mortgage(confirmed.mortgages[0])[1].date) == "2026-03-31")
        var bad = snapshot
        bad.mortgages[0].annualPercent = .nan
        precondition(LiabilityRules.error(bad, kind: .mortgage) != nil)
        bad = snapshot; bad.mortgages[0].months = 0
        precondition(LiabilityRules.error(bad, kind: .mortgage) != nil)
        precondition(LiabilityRules.sum([LiabilityRules.maximum, 1]) == nil)
        var plan = CardInstallment(name: "家电", principal: 12000_00, months: 12, nextDate: next, dueDay: 31, monthlyFee: 3000)
        var card = LiabilitySnapshot(balanceDate: baseline, cardTotal: 20000_00, billDue: 5000_00, billDate: next, installments: [plan])
        precondition(LiabilityRules.error(card, kind: .creditCard) == nil)
        let cardRows = LiabilityRules.payments(card, kind: .creditCard)
        precondition(cardRows.count == 12 && cardRows[0].total == 5000_00)
        precondition(cardRows[1].total == 1030_00) // No duplicate current installment.
        precondition(LiabilityRules.balance(card, kind: .creditCard) == 20000_00)
        let paid = LiabilityRules.confirmed(card, kind: .creditCard, on: next)!
        precondition(paid.cardTotal == 15000_00 && paid.billDue == nil)
        precondition(paid.installments[0].principal == 11000_00 && paid.installments[0].months == 11)
        card.cardTotal = 12000_00
        precondition(LiabilityRules.error(card, kind: .creditCard) != nil) // Future principal must still be covered.
        card.cardTotal = 20000_00; card.billDue = 500_00
        precondition(LiabilityRules.error(card, kind: .creditCard) != nil)
        card.billDue = nil
        precondition(LiabilityRules.payments(card, kind: .creditCard).first!.total == 1030_00)
        plan.firstFee = 100_00; plan.lastFee = 0
        let feeRows = LiabilityRules.installments(plan)
        precondition(feeRows.first!.interest == 100_00 && feeRows.last!.interest == 0 && feeRows[1].interest == 3000)
        let cents = CardInstallment(name: "尾期", principal: 100, months: 3, nextDate: next)
        precondition(LiabilityRules.installments(cents).map(\.principal) == [33,33,34])
        // An isolated store verifies decoding and persistence without touching app/iCloud data.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([LiabilityAccount.self])
        let config = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("test.store"), cloudKitDatabase: .none)
        let id: String
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let record = LiabilityAccount(); id = record.id
            record.name = "组合贷"; record.snapshotData = try JSONEncoder().encode(snapshot)
            record.historyData = try JSONEncoder().encode([LiabilityRevision(date: baseline, reason: "校准", snapshot: snapshot)])
            container.mainContext.insert(record); try container.mainContext.save()
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let records = try container.mainContext.fetch(FetchDescriptor<LiabilityAccount>())
            precondition(records.count == 1 && records[0].id == id)
            precondition(records[0].snapshot!.mortgages.count == 2 && records[0].history!.count == 1)
            let copy = LiabilityAccount(); copy.id = id; copy.modifiedAt = .distantFuture
            copy.snapshotData = try JSONEncoder().encode(snapshot)
            precondition(LiabilityRules.accounts([records[0], copy]).count == 1)
        }
        let memory = try ModelContainer(for: LiabilityAccount.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        try LiabilityStore.save(snapshot, name: "组合贷", kind: .mortgage, account: nil, reason: "新增", context: memory.mainContext)
        let stored = try memory.mainContext.fetch(FetchDescriptor<LiabilityAccount>()).first!
        var cancelledDraft = stored.snapshot!
        cancelledDraft.mortgages[0].principal = 1
        precondition(stored.snapshot!.mortgages[0].principal == annuity.principal)
        try LiabilityStore.save(confirmed, name: stored.name, kind: .mortgage, account: stored, reason: "确认还款", context: memory.mainContext)
        precondition(stored.history!.count == 1 && stored.snapshot!.mortgages[0].principal == confirmed.mortgages[0].principal)
        var invalid = confirmed; invalid.mortgages[0].months = 0
        do {
            try LiabilityStore.save(invalid, name: stored.name, kind: .mortgage, account: stored, reason: "无效", context: memory.mainContext)
            preconditionFailure("Invalid snapshot must not save")
        } catch { precondition(stored.snapshot!.mortgages[0].months == confirmed.mortgages[0].months) }
        print("Liability amortization, zero interest, month ends, rounding, bills, installments, confirmations and isolated persistence passed")
    }
}
