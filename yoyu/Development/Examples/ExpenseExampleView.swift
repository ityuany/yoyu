import SwiftUI
import SwiftData

/// A separate in-memory container allows exploration without changing the user's plans.
struct ExpenseExampleView: View {
    var showsDuplicateExample = false
    @State private var container: ModelContainer?
    @State private var failure: String?
    var body: some View {
        Group {
            if let container { ExpenseListView(isExample: true).modelContainer(container) }
            else if let failure { ContentUnavailableView("无法加载示例", systemImage: "exclamationmark.circle", description: Text(failure)) }
            else { ProgressView("准备示例…") }
        }.task {
            guard container == nil else { return }
            do {
                let schema = Schema([RecurringExpense.self, LiabilityAccount.self])
                let sample = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
                let first = ExpenseRules.month(Date())
                let last = ExpenseRules.calendar.date(byAdding: .day, value: -1, to: ExpenseRules.calendar.date(byAdding: .month, value: 3, to: first)!)!
                for plan in [
                    ExpensePlan(name: "生活费", amount: 3000_00, start: first),
                    ExpensePlan(name: "异地租房", amount: 2000_00, estimated: false, start: first, end: last, spreadAcrossMonth: false, dueDay: 1),
                    ExpensePlan(name: "软件订阅", amount: 98_00, estimated: false, start: first, spreadAcrossMonth: false, dueDay: 8)
                ] { try ExpenseStore.save(plan, record: nil, context: sample.mainContext) }
                if showsDuplicateExample {
                    let mortgage = LiabilityAccount()
                    mortgage.name = "房贷"
                    mortgage.apply(LiabilitySnapshot(
                        balanceDate: ExpenseRules.calendar.date(byAdding: .day, value: -1, to: first)!,
                        mortgages: [.init(principal: 12000_00, annualPercent: 0, months: 12,
                                          nextDate: first, dueDay: 10)]))
                    sample.mainContext.insert(mortgage)
                    try ExpenseStore.save(ExpensePlan(name: "房贷还款副本", amount: 1000_00,
                        start: first, spreadAcrossMonth: false, dueDay: 10,
                        coveredByLiabilityID: mortgage.id), record: nil, context: sample.mainContext)
                }
                container = sample
            } catch { failure = error.localizedDescription }
        }
    }
}
