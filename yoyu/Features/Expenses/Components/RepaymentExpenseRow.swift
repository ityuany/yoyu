import SwiftUI
import SwiftData

struct RepaymentExpenseRow: View {
    let account: LiabilityAccount
    let month: Date
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: account.kind?.icon ?? "creditcard").foregroundStyle(DashboardStyle.accent).frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                Text(account.name)
                Text("\(account.kind?.title ?? "负债")还款 · 自动引用").font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
            Spacer(minLength: 8)
            Text(ExpectedExpenseRules.repayment(account, in: month).map { ProfileRules.money($0) } ?? "待核对").monospacedDigit()
        }.padding(.vertical, 3)
    }
}
