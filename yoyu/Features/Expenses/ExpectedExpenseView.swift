import SwiftUI
import SwiftData

struct ExpectedExpenseView: View {
    @Query private var records: [RecurringExpense]
    @Query private var liabilities: [LiabilityAccount]
    @State private var month: Date
    init(initialMonth: Date = Date()) {
        _month = State(initialValue: ExpenseRules.month(initialMonth))
    }
    @State private var adding = false
    private var accounts: [LiabilityAccount] { LiabilityRules.accounts(liabilities) }
    var body: some View {
        List {
            Section {
                HStack {
                    Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }.accessibilityLabel("上个月")
                    Spacer()
                    Text(ExpenseRules.monthLabel(month)).font(.headline)
                    Spacer()
                    Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }.accessibilityLabel("下个月")
                }.buttonStyle(.borderless)
                VStack(alignment: .leading, spacing: 8) {
                    Text("当月预计支出 · 含已知还款与预估开支").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                    DashboardAmount(value: ExpectedExpenseRules.total(expenses: records, liabilities: accounts, in: month).map { ProfileRules.money($0) } ?? "待核对")
                }.padding(.vertical, 6)
            } footer: {
                Text("按当前已知计划汇总，包含还款本金与利息／费用。已确认并移出计划的还款不补记，不代表实际消费流水。")
            }.listRowBackground(AppTheme.cardBackground)
            Section {
                if accounts.isEmpty { Text("暂无负债还款计划").foregroundStyle(AppTheme.secondaryText) }
                ForEach(accounts) { account in
                    NavigationLink { LiabilityDetailView(accountID: account.id) } label: { RepaymentExpenseRow(account: account, month: month) }
                }
                if ExpectedExpenseRules.missingBills(accounts) {
                    Label("部分信用卡账单未录入，当前仅计入已知还款。", systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(AppTheme.secondaryText)
                }
            } header: { Text("负债还款") }.listRowBackground(AppTheme.cardBackground)
            Section {
                ForEach(ExpenseRules.records(records)) { record in
                    NavigationLink { ExpenseDetailView(recordID: record.id) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ExpenseRow(record: record, date: month, monthView: true)
                            if let plan = record.plan {
                                Text(ExpectedExpenseRules.isCovered(record, liabilities: accounts)
                                     ? "已包含在负债还款中，本处不重复计入"
                                     : "当月计入 \(ExpenseRules.amount(plan, in: month).map { ProfileRules.money($0) } ?? "待核对")")
                                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                    }
                }
                if records.isEmpty { Text("尚未添加日常开支，已有还款已计入上方合计。").font(.subheadline).foregroundStyle(AppTheme.secondaryText) }
                Button { adding = true } label: { Label("添加日常开支", systemImage: "plus") }
                NavigationLink("管理日常开支") { ExpenseListView() }
                if records.isEmpty { NavigationLink("查看日常开支示例") { ExpenseExampleView() } }
            } header: { Text("日常开支") } footer: { Text("仅添加还款以外的开支，避免重复录入房贷或信用卡分期。") }.listRowBackground(AppTheme.cardBackground)
        }.neutralPageBackground()
        .navigationTitle("预计支出").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $adding) { ExpenseEditor() }
    }
    private func move(_ offset: Int) { month = ExpenseRules.calendar.date(byAdding: .month, value: offset, to: month)! }
}
