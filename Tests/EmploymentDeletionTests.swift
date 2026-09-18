import Foundation
import SwiftData

@main struct EmploymentDeletionTests {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([Employment.self, SalaryStage.self, StockHolding.self, UserProfile.self])
        let config = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("delete.store"), cloudKitDatabase: .none)
        let targetID = "delete-company"
        var otherID = ""
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let job = Employment(); job.id = targetID; job.name = "测试企业"
            let duplicate = Employment(); duplicate.id = targetID; duplicate.name = job.name
            let other = Employment(); otherID = other.id
            context.insert(job); context.insert(duplicate); context.insert(other)
            for company in [targetID, targetID, otherID] {
                let stage = SalaryStage(); stage.employmentID = company; context.insert(stage)
            }
            let stock = StockHolding(); stock.employmentID = targetID
            stock.initialSharesHundredths = 12300; stock.priceCents = 456
            stock.grantData = Data("preserved grants".utf8)
            stock.disposalData = Data("preserved disposals".utf8)
            context.insert(stock)
            let duplicateStock = StockHolding(); duplicateStock.id = stock.id
            duplicateStock.employmentID = targetID; context.insert(duplicateStock)
            let otherStock = StockHolding(); otherStock.employmentID = otherID; context.insert(otherStock)
            let legacy = UserProfile(); legacy.careerMigrated = true; context.insert(legacy)
            try context.save()
            // 未确认时没有更改；确认后同时清理所有副本与薪资阶段。
            precondition((try? context.fetchCount(FetchDescriptor<Employment>())) == 3)
            enum SaveFailure: Error { case simulated }
            do {
                try EmploymentDeletion.delete(id: targetID, context: context, save: { _ in
                    throw SaveFailure.simulated
                })
                preconditionFailure("Expected save failure")
            } catch SaveFailure.simulated { }
            precondition((try? context.fetchCount(FetchDescriptor<Employment>())) == 3)
            precondition((try? context.fetchCount(FetchDescriptor<SalaryStage>())) == 3)
            precondition((try? context.fetchCount(FetchDescriptor<StockHolding>())) == 3)
            precondition(stock.employmentID == targetID)
            precondition(stock.grantData == Data("preserved grants".utf8))
            precondition(stock.disposalData == Data("preserved disposals".utf8))
            try EmploymentDeletion.delete(id: targetID, context: context)
            precondition((try? context.fetchCount(FetchDescriptor<Employment>())) == 1)
            precondition((try? context.fetchCount(FetchDescriptor<SalaryStage>())) == 1)
            let remainingStocks = try context.fetch(FetchDescriptor<StockHolding>())
            precondition(remainingStocks.count == 1 && remainingStocks[0].employmentID == otherID)
            precondition(otherStock.employmentID == otherID && legacy.careerMigrated)
            try EmploymentDeletion.delete(id: targetID, context: context)
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let jobs = try context.fetch(FetchDescriptor<Employment>())
            let stages = try context.fetch(FetchDescriptor<SalaryStage>())
            let stocks = try context.fetch(FetchDescriptor<StockHolding>())
            precondition(jobs.count == 1 && jobs[0].id == otherID)
            precondition(stages.count == 1 && stages[0].employmentID == otherID)
            precondition(stocks.count == 1 && stocks.allSatisfy { $0.employmentID != targetID })
            try EmploymentDeletion.delete(id: otherID, context: context)
            precondition((try? context.fetchCount(FetchDescriptor<Employment>())) == 0)
            precondition((try? context.fetchCount(FetchDescriptor<SalaryStage>())) == 0)
            precondition((try? context.fetchCount(FetchDescriptor<StockHolding>())) == 0)
        }
        print("Employment deletion, duplicate cleanup, stock cascade deletion, rollback and persistence tests passed")
    }
}
