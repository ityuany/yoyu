import SwiftUI
import SwiftData

struct ExpenseEditor: View {
    var record: RecurringExpense?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ExpensePlan
    @State private var amount: String
    @State private var limited: Bool
    @State private var end: Date
    @State private var errorMessage: String?

    init(record: RecurringExpense? = nil) {
        self.record = record
        let plan = record?.plan ?? ExpensePlan()
        _draft = State(initialValue: plan)
        _amount = State(initialValue: plan.amount > 0 ? ProfileRules.input(plan.amount) : "")
        _limited = State(initialValue: plan.end != nil)
        _end = State(initialValue: plan.end ?? ExpenseRules.calendar.date(byAdding: .year, value: 1, to: plan.start)!)
    }
    private var plan: ExpensePlan {
        var value = draft
        value.amount = ProfileRules.scaledValue(amount) ?? 0
        value.end = limited ? end : nil
        return value
    }
    private var error: String? { ExpenseRules.error(plan) }

    var body: some View {
        NavigationStack {
            Form {
                Section("用途与金额") {
                    TextField("用途，如生活费、租金、订阅", text: $draft.name)
                        .accessibilityLabel("开支用途")
                    HStack {
                        Text("每期金额")
                        TextField("0.00", text: $amount).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).monospacedDigit().accessibilityLabel("每期金额")
                        Text("元").foregroundStyle(.secondary)
                    }
                    Picker("金额类型", selection: $draft.estimated) {
                        Text("预估金额").tag(true)
                        Text("固定金额").tag(false)
                    }
                }
                Section {
                    Picker("重复周期", selection: $draft.frequency) {
                        ForEach(ExpenseFrequency.allCases) { Text($0.title).tag($0) }
                    }
                    if draft.frequency == .monthly {
                        Picker("发生方式", selection: $draft.spreadAcrossMonth) {
                            Text("月内陆续发生").tag(true)
                            Text("指定日期扣款").tag(false)
                        }
                    }
                    if draft.spreadAcrossMonth {
                        DatePicker("开始日期", selection: $draft.start, displayedComponents: .date)
                    } else {
                        DatePicker("首次扣款日期", selection: Binding(
                            get: { ExpenseRules.firstPaymentDate(draft) },
                            set: { date in
                                draft.start = date
                                draft.dueDay = ExpenseRules.calendar.component(.day, from: date)
                            }
                        ), displayedComponents: .date)
                        Text(ExpenseRules.scheduleLabel(draft))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(ExpenseRules.paymentPreview(plan).isEmpty ? "当前起止范围内没有扣款，请调整日期。" : "接下来：" + ExpenseRules.paymentPreview(plan).map { ExpenseRules.dateLabel($0) }.joined(separator: "、"))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Toggle("指定结束日期", isOn: $limited)
                    if limited { DatePicker("结束日期", selection: $end, displayedComponents: .date) }
                } header: { Text("发生时间") } footer: {
                    Text(draft.spreadAcrossMonth
                         ? "按月估算，首尾不足整月时按有效天数折算，包含开始与结束当天。"
                         : "从首次扣款日起重复，每季度指每隔 3 个月。遇到没有该日期的月份取月末，之后恢复原日期；结束日期当天仍计入。")
                }
                Section("备注") { TextField("选填", text: $draft.note, axis: .vertical).lineLimit(2...4) }
                if error == nil {
                    Section {
                        LabeledContent("\(ExpenseRules.monthLabel(draft.start))预计", value: ProfileRules.money(ExpenseRules.amount(plan, in: draft.start)))
                        Text("\(draft.frequency.title) \(ProfileRules.money(plan.amount)) · \(draft.estimated ? "预估" : "固定")")
                            .foregroundStyle(.secondary)
                        Text(ExpenseRules.period(plan)).font(.subheadline).foregroundStyle(.secondary)
                    } header: { Text("计划预览") } footer: {
                        Text("保存计划不会扣减现金，也不会生成实际消费记录。房贷与信用卡还款请在负债中管理。")
                    }
                } else if let error {
                    Section { Text(error).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .neutralPageBackground()
            .environment(\.timeZone, ExpenseRules.calendar.timeZone)
            .navigationTitle(record == nil ? "添加日常开支" : "编辑日常开支")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save).disabled(error != nil) }
            }
            .onChange(of: draft.frequency) { _, value in
                if value != .monthly { draft.spreadAcrossMonth = false }
            }
            .onChange(of: draft.spreadAcrossMonth) { previous, current in
                if previous && !current { draft.dueDay = ExpenseRules.calendar.component(.day, from: draft.start) }
            }
            .saveErrorAlert($errorMessage)
        }
    }
    private func save() {
        do { try ExpenseStore.save(plan, record: record, context: context); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}
