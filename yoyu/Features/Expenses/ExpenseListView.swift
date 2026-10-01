import SwiftUI
import SwiftData

struct ExpenseListView: View {
    var isExample = false
    @Environment(\.modelContext) private var context
    @Query private var records: [RecurringExpense]
    @Query private var liabilities: [LiabilityAccount]
    @State private var month = ExpenseRules.month(Date())
    @State private var adding = false
    private var items: [RecurringExpense] { ExpenseRules.records(records) }
    var body: some View {
        List {
            if isExample {
                Section { Label("示例计划 · 可体验编辑，不写入你的记录", systemImage: "sparkles").font(.subheadline) }.listRowBackground(AppTheme.cardBackground)
            }
            Section {
                HStack {
                    Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }.accessibilityLabel("上个月")
                    Spacer()
                    Text(ExpenseRules.monthLabel(month)).font(.headline).monospacedDigit()
                    Spacer()
                    Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }.accessibilityLabel("下个月")
                }.buttonStyle(.borderless)
                VStack(alignment: .leading, spacing: 8) {
                    Text("当月日常开支 · 含预估").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                    DashboardAmount(value: ExpenseRules.total(ExpectedExpenseRules.uncoveredExpenses(items, liabilities: liabilities), in: month).map { ProfileRules.money($0) } ?? "待核对")
                }.padding(.vertical, 6)
            } footer: { Text("仅汇总当月日常开支，不含房贷与信用卡还款，不扣减现金余额。") }.listRowBackground(AppTheme.cardBackground)
            if items.isEmpty {
                Section { ContentUnavailableView("还没有日常开支", systemImage: "repeat", description: Text("添加一项开支，开始安排未来的生活。")) }.listRowBackground(AppTheme.cardBackground)
            }
            Section("开支计划") {
                ForEach(items) { record in
                    NavigationLink { ExpenseDetailView(recordID: record.id).modelContainer(context.container) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ExpenseRow(record: record, date: month, monthView: true)
                            if let plan = record.plan {
                                Text((ExpectedExpenseRules.isCovered(record, liabilities: liabilities)
                                      ? "已包含在负债还款中，本处不重复计入"
                                      : "当月计入 \(ExpenseRules.amount(plan, in: month).map { ProfileRules.money($0) } ?? "待核对")") + " · \(ExpenseRules.period(plan))")
                                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                    }
                }
            }.listRowBackground(AppTheme.cardBackground)
        }.neutralPageBackground()
        .navigationTitle("日常开支").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("添加", systemImage: "plus") { adding = true } } }
        .sheet(isPresented: $adding) { ExpenseEditor() }
    }
    private func move(_ offset: Int) { month = ExpenseRules.calendar.date(byAdding: .month, value: offset, to: month)! }
}
