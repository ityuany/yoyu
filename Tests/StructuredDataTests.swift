import Foundation
import SwiftData

@main struct StructuredDataTests {
    @MainActor static func main() throws {
        func check(_ condition: Bool) { precondition(condition) }
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let schema = Schema([Employment.self, StockHolding.self, LiabilityAccount.self, RecurringExpense.self, RunwaySettings.self])
        func open() throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        }
        func migrateAndCheck() throws {
            let container = try open()
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let job = try context.fetch(FetchDescriptor<Employment>()).first!
            let holding = try context.fetch(FetchDescriptor<StockHolding>()).first!
            let account = try context.fetch(FetchDescriptor<LiabilityAccount>()).first!
            let expense = try context.fetch(FetchDescriptor<RecurringExpense>()).first { $0.id == "expense" }!
            let invalid = try context.fetch(FetchDescriptor<RecurringExpense>()).first { $0.id == "invalid" }!
            let runway = try context.fetch(FetchDescriptor<RunwaySettings>()).first!
            // 实际旧版数据库已经成功以新增字段和关系的结构打开。
            check(!expense.hasStructuredPlan && expense.plan?.amount == 3100_00)
            let originalJSON = expense.planData
            try StructuredDataMigration.run(context: context)
            check(expense.hasStructuredPlan && expense.amount == 3100_00 && expense.frequencyRaw == 3)
            check(expense.plan?.pausesDuringWorkBreak == true && expense.coveredByLiabilityID == account.id)
            check(expense.planData == originalJSON)
            check(!invalid.hasStructuredPlan && invalid.plan == nil && invalid.planData == Data([0]))
            check(runway.hasStructuredPlan && runway.plan?.mode == .temporary && runway.salary == 1234_00)
            check(job.hasStructuredSeverance && SeveranceRules.settings(for: job)?.plan == .twoN)
            check(job.severanceTripleAverageSalaryCents == 20000_00)
            check(holding.hasStructuredGrants && holding.grants?.count == 1)
            check(holding.grants?.first?.installments.count == 2 && holding.grants?.first?.installments.last?.cancelled == true)
            check(holding.disposals?.first?.shares == 100)
            check(account.snapshot?.mortgages.first?.principal == 12000_00)
            check(account.snapshot?.installments.first?.terms?.paid == 2)
            check(account.snapshot?.installments.first?.terms?.automatic == false)
            check(try context.fetchCount(FetchDescriptor<EquityGrantRecord>()) == 1)
            check(try context.fetchCount(FetchDescriptor<EquityInstallmentRecord>()) == 2)
            check(try context.fetchCount(FetchDescriptor<EquityDisposalRecord>()) == 1)
            check(try context.fetchCount(FetchDescriptor<MortgagePartRecord>()) == 1)
            check(try context.fetchCount(FetchDescriptor<CardInstallmentRecord>()) == 1)
            try StructuredDataMigration.run(context: context)
            check(try context.fetchCount(FetchDescriptor<EquityInstallmentRecord>()) == 2)
            // 结构化金额能够直接查询，不需要先解码 JSON。
            let amount: Int64 = 3100_00
            check(try context.fetchCount(FetchDescriptor<RecurringExpense>(predicate: #Predicate { $0.amount == amount })) == 1)
            // 两台设备从同一旧数据迁移出同源批次时，读取按业务 ID 归并。
            let duplicateGrant = EquityGrantRecord()
            let originalGrant = holding.grantRecords!.first!
            duplicateGrant.id = originalGrant.id; duplicateGrant.name = originalGrant.name
            duplicateGrant.date = originalGrant.date; duplicateGrant.shares = originalGrant.shares
            duplicateGrant.position = originalGrant.position
            duplicateGrant.modifiedAt = originalGrant.modifiedAt.addingTimeInterval(-1)
            duplicateGrant.applyInstallments(originalGrant.value!.installments)
            holding.grantRecords!.append(duplicateGrant)
            try context.save()
            check(holding.grants?.count == 1 && holding.grants?.first?.installments.count == 2)
            // 编辑时保持稳定子记录身份，回滚能够还原字段、关系及删除操作。
            let persistentID = originalGrant.persistentModelID
            var grants = holding.grants!
            grants[0].name = "修改后"
            grants[0].installments.removeLast()
            holding.applyGrants(grants)
            try context.save()
            check(holding.grantRecords!.first!.persistentModelID == persistentID)
            check(try context.fetchCount(FetchDescriptor<EquityInstallmentRecord>()) == 1)
            check(try context.fetchCount(FetchDescriptor<EquityGrantRecord>()) == 1)
            context.rollback()
            var modified = expense.plan!
            modified.amount = 999_00
            expense.apply(modified)
            holding.applyGrants([])
            account.apply(LiabilitySnapshot())
            context.rollback()
            check(expense.amount == 3100_00 && holding.grants?.count == 1)
            check(account.snapshot?.mortgages.count == 1)
            // 云端关系未到齐时，返回待核对而不是将缺失明细当成零。
            holding.grantCount += 1
            check(holding.grants == nil)
            context.rollback()
            account.installmentCount += 1
            check(account.snapshot == nil)
            context.rollback()
            // 新记录不写任何 JSON 字段。
            let newExpense = RecurringExpense(); newExpense.apply(expense.plan!); context.insert(newExpense)
            let newRunway = RunwaySettings(); newRunway.apply(runway.plan!); context.insert(newRunway)
            let newJob = Employment(); newJob.applySeverance(SeveranceSettings()); context.insert(newJob)
            let newHolding = StockHolding(); newHolding.applyGrants(holding.grants!); newHolding.applyDisposals([]); context.insert(newHolding)
            let newAccount = LiabilityAccount(); newAccount.apply(account.snapshot!); context.insert(newAccount)
            try context.save()
            check(newExpense.planData == nil && newRunway.data == nil && newJob.severanceData == nil)
            check(newHolding.grantData == nil && newHolding.disposalData == nil && newHolding.vestingData == nil)
            check(newAccount.snapshotData == nil)
        }
        try migrateAndCheck()
        func reopenAndDelete() throws {
            let container = try open(); let context = ModelContext(container)
            let holdings = try context.fetch(FetchDescriptor<StockHolding>())
            let accounts = try context.fetch(FetchDescriptor<LiabilityAccount>())
            check(holdings.count == 2 && holdings.allSatisfy { $0.grants?.first?.name == "修改后" })
            check(accounts.count == 2 && accounts.allSatisfy { $0.snapshot?.mortgages.first?.principal == 12000_00 })
            // 子记录均具有反向关系，父记录删除会级联清理。
            check(try context.fetch(FetchDescriptor<EquityInstallmentRecord>()).allSatisfy { $0.grant != nil })
            check(try context.fetch(FetchDescriptor<CardInstallmentRecord>()).allSatisfy { $0.account != nil })
            for holding in holdings { context.delete(holding) }
            for account in accounts { context.delete(account) }
            try context.save()
            check(try context.fetchCount(FetchDescriptor<EquityGrantRecord>()) == 0)
            check(try context.fetchCount(FetchDescriptor<EquityInstallmentRecord>()) == 0)
            check(try context.fetchCount(FetchDescriptor<EquityDisposalRecord>()) == 0)
            check(try context.fetchCount(FetchDescriptor<MortgagePartRecord>()) == 0)
            check(try context.fetchCount(FetchDescriptor<CardInstallmentRecord>()) == 0)
        }
        try reopenAndDelete()
        print("Structured data tests passed: legacy store upgrade, JSON import, direct queries, idempotency, invalid data, stable identity, rollback, partial relationships, reopen and cascade deletion")
    }
}
