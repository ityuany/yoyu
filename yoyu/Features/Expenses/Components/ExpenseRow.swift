import SwiftUI
import SwiftData

struct ExpenseRow: View {
    let record: RecurringExpense
    let date: Date
    var monthView = false
    var body: some View {
        if let plan = record.plan {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "repeat").foregroundStyle(DashboardStyle.accent).frame(width: 22).padding(.top, 3)
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.name).foregroundStyle(AppTheme.primaryText)
                    Text("\(plan.estimated ? "预估" : "固定") · \(plan.frequency.title) · \(monthView ? ExpenseRules.monthStatus(plan, in: date) : ExpenseRules.status(plan, on: date))")
                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(ProfileRules.money(plan.amount)).monospacedDigit().foregroundStyle(AppTheme.primaryText)
                    Text("/ \(plan.frequency.unit)").font(.caption).foregroundStyle(AppTheme.secondaryText)
                }
            }.padding(.vertical, 3)
        } else {
            Label("开支记录待核对", systemImage: "exclamationmark.circle")
        }
    }
}
