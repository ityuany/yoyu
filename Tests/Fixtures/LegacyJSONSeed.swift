import Foundation
import SwiftData

@main struct LegacyJSONSeed {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let schema = Schema([Employment.self, StockHolding.self, LiabilityAccount.self, RecurringExpense.self, RunwaySettings.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000).timeIntervalSinceReferenceDate
        func data(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
        let job = Employment(); job.id = "job"
        job.severanceData = try data(["plan": "twoN", "tripleAverageSalaryCents": 20000_00])
        let holding = StockHolding(); holding.id = "holding"
        holding.grantData = try data([["id": UUID().uuidString, "name": "授予", "date": date, "shares": 300,
            "installments": [["id": UUID().uuidString, "date": date, "shares": 100, "cancelled": false],
                             ["id": UUID().uuidString, "date": date, "shares": 200, "cancelled": true]]]])
        holding.disposalData = try data([["id": UUID().uuidString, "date": date, "shares": 100]])
        let account = LiabilityAccount(); account.id = "account"
        account.snapshotData = try data(["balanceDate": date, "cardTotal": 1000_00, "billDate": date, "note": "备注",
            "mortgages": [["id": UUID().uuidString, "name": "商业贷款", "principal": 12000_00, "annualPercent": 3,
                           "months": 12, "method": "annuity", "nextDate": date, "dueDay": 10]],
            "installments": [["id": UUID().uuidString, "name": "分期", "principal": 1000_00, "months": 12,
                              "nextDate": date, "dueDay": 10, "monthlyFee": 5_00,
                              "terms": ["rate": 0.3, "mode": "monthlyFee", "paid": 2, "automatic": false]]]])
        let expense = RecurringExpense(); expense.id = "expense"
        expense.planData = try data(["name": "生活费", "amount": 3100_00, "estimated": false, "frequency": 3,
            "start": date, "spreadAcrossMonth": false, "dueDay": 10, "note": "备注", "coveredByLiabilityID": "account", "pausesDuringWorkBreak": true])
        let invalid = RecurringExpense(); invalid.id = "invalid"; invalid.planData = Data([0])
        let runway = RunwaySettings(); runway.mode = "temporary"
        runway.data = try data(["mode": "temporary", "lossDate": date, "returnDate": date + 86400,
            "salary": 1234_00, "payday": 10, "flexible": 50_00, "flexibleDay": 20])
        context.insert(job); context.insert(holding); context.insert(account); context.insert(expense); context.insert(invalid); context.insert(runway)
        try context.save()
        print("Legacy JSON store created")
    }
}
