import SwiftUI
import SwiftData

struct ExpenseDetailView: View {
    let recordID: String
    @Query private var records: [RecurringExpense]
    @Query private var liabilities: [LiabilityAccount]
    @Environment(CareerClock.self) private var clock
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var deleting = false
    @State private var errorMessage: String?
    private var record: RecurringExpense? { ExpenseRules.records(records).first { $0.id == recordID } }
    var body: some View {
        Group {
            if let record, let plan = record.plan {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(plan.estimated ? "预估金额" : "固定金额") · \(plan.frequency.title)").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                            DashboardAmount(value: ProfileRules.money(plan.amount))
                            Text(ExpenseRules.status(plan, on: clock.now)).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                        }.padding(.vertical, 8)
                    }.listRowBackground(AppTheme.cardBackground)
                    Section("发生时间") {
                        LabeledContent("开始日期", value: ExpenseRules.dateLabel(plan.start))
                        LabeledContent("结束日期", value: plan.end.map { ExpenseRules.dateLabel($0) } ?? "长期持续")
                        LabeledContent("发生方式", value: ExpenseRules.scheduleLabel(plan))
                        LabeledContent("工作中断时", value: plan.pausesDuringWorkBreak == true ? "暂停，复工后继续" : "照常计入")
                            .accessibilityIdentifier("expense.workBreakBehavior")
                    }.listRowBackground(AppTheme.cardBackground)
                    if ExpectedExpenseRules.isCovered(record, liabilities: liabilities) {
                        Section {
                            Text("已包含在负债还款中；预计支出汇总和生存时长预测只计负债还款。")
                        }.listRowBackground(AppTheme.cardBackground)
                    }
                    Section {
                        ForEach(0..<12, id: \.self) { offset in
                            let date = ExpenseRules.calendar.date(byAdding: .month, value: offset, to: ExpenseRules.month(clock.now))!
                            LabeledContent(ExpenseRules.monthLabel(date), value: ExpectedExpenseRules.isCovered(record, liabilities: liabilities) ? "已计入负债" : (ExpenseRules.amount(plan, in: date).map { ProfileRules.money($0) } ?? "待核对"))
                                .monospacedDigit()
                        }
                    } header: { Text("未来 12 个月") } footer: {
                        Text("按当前计划估算，包含本月整月。未开始、已结束或没有扣款的月份计为零；不代表实际消费。")
                    }.listRowBackground(AppTheme.cardBackground)
                    if !plan.note.isEmpty { Section("备注") { Text(plan.note) }.listRowBackground(AppTheme.cardBackground) }
                    Section { Button("删除开支计划", role: .destructive) { deleting = true } }.listRowBackground(AppTheme.cardBackground)
                }.neutralPageBackground()
                .navigationTitle(plan.name).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .primaryAction) { Button("编辑") { editing = true } } }
                .sheet(isPresented: $editing) { ExpenseEditor(record: record) }
            } else {
                ContentUnavailableView("开支记录不可用", systemImage: "exclamationmark.circle", description: Text("记录可能已被删除或暂时无法读取。"))
            }
        }
        .alert("删除这项开支计划？", isPresented: $deleting) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                do { try ExpenseStore.delete(id: recordID, context: context); dismiss() }
                catch { errorMessage = error.localizedDescription }
            }
        } message: { Text("删除后，这项开支不再计入预计支出。不会修改现金或负债。") }
        .saveErrorAlert($errorMessage)
    }
}
