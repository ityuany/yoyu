import SwiftUI
import SwiftData

struct ForecastScenarioEditor: View {
    let cash: Int64?
    let grossSalary: Int64?
    let investment: Int64?
    let origin: Date
    let records: [ForecastScenarioRecord]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ForecastScenario
    @State private var salary: String
    @State private var newSalary: String
    @State private var errorMessage: String?

    init(scenario: ForecastScenario, origin: Date, records: [ForecastScenarioRecord], cash: Int64?, grossSalary: Int64?, investment: Int64?) {
        self.cash = cash
        self.grossSalary = grossSalary
        self.investment = investment
        self.origin = origin
        self.records = records
        _draft = State(initialValue: scenario)
        _salary = State(initialValue: scenario.currentIncome.map(ProfileRules.input) ?? "")
        _newSalary = State(initialValue: scenario.returnIncome.map(ProfileRules.input) ?? "")
    }
    private var value: ForecastScenario {
        var result = draft
        result.openingFunds = nil
        result.currentIncome = ProfileRules.scaledValue(salary)
        result.returnIncome = ProfileRules.scaledValue(newSalary)
        result.fundsMonth = origin
        return result
    }
    private var validation: String? {
        let entries = [salary] + (draft.mode == .temporaryBreak ? [newSalary] : [])
        if entries.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty && ProfileRules.scaledValue($0) == nil }) {
            return "金额请填写非负数字，最多两位小数。"
        }
        return ScenarioForecast.error(value)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(ForecastWorkMode.allCases) { mode in
                        Button { draft.mode = mode } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mode.icon).font(.title3).frame(width: 26)
                                    .foregroundStyle(draft.mode == mode ? DashboardStyle.cash : .secondary)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(mode.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                                    Text(mode.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: draft.mode == mode ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(draft.mode == mode ? DashboardStyle.cash : .secondary)
                            }.padding(.vertical, 5).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("scenario.mode.\(mode.rawValue)")
                        .accessibilityAddTraits(draft.mode == mode ? .isSelected : [])
                    }
                } header: { Text("选择工作情景") } footer: {
                    Text("只是一次对未来的假设，不会修改真实职业履历。")
                }
                if draft.mode != .employed {
                    Section {
                        DatePicker("失业开始日期", selection: $draft.breakStart, displayedComponents: .date)
                            .accessibilityIdentifier("scenario.breakStart")
                        if draft.mode == .temporaryBreak {
                            HStack {
                                Text("预计中断").font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                ForEach([1, 3, 6], id: \.self) { count in
                                    Button("\(count)个月") {
                                        draft.returnDate = ProfileRules.calendar.date(byAdding: .month, value: count, to: draft.breakStart)!
                                    }
                                    .buttonStyle(.bordered).controlSize(.small)
                                    .accessibilityIdentifier("scenario.duration.\(count)")
                                }
                            }
                            DatePicker("预计再就业日期", selection: $draft.returnDate, displayedComponents: .date)
                                .accessibilityIdentifier("scenario.returnDate")
                            moneyField("再就业月到手收入", text: $newSalary, id: "scenario.returnIncome")
                        }
                    } header: { Text("工作中断安排") } footer: {
                        Text(draft.mode == .temporaryBreak
                             ? "失业开始日不再计入工资，再就业当天恢复。快捷时长之外，也可以直接选择日期。"
                             : "从这一天起，不再计入工作收入。之后仍可调整情景。")
                    }
                }
                Section {
                    LabeledContent("可用现金 · 关联财富", value: cash.map { ProfileRules.money($0) } ?? "请在财富中补充")
                    if let grossSalary {
                        LabeledContent("当前税前月薪 · 关联职业", value: ProfileRules.money(grossSalary))
                    }
                    moneyField("确认月到手收入", text: $salary, id: "scenario.currentIncome")
                } header: { Text("计算基础 · 今天起") } footer: {
                    Text("现金自动沿用财富记录。职业记录是税前口径，到手金额只需确认一次，后续沿用；留空表示未知，0 表示没有。工资按自然日折算，本月只计今天及之后，已发生收支不重复累计。")
                }
                Section {
                    LabeledContent("当前理财估值 · 关联财富", value: investment.map { ProfileRules.money($0) } ?? "未配置")
                    Toggle("预测期间赎回理财", isOn: Binding(get: { draft.redemptionDate != nil }, set: { draft.redemptionDate = $0 ? origin : nil }))
                    if draft.redemptionDate != nil {
                        DatePicker("预计赎回日期", selection: Binding(get: { draft.redemptionDate ?? origin }, set: { draft.redemptionDate = $0 }), in: origin..., displayedComponents: .date)
                            .accessibilityIdentifier("scenario.redemptionDate")
                    }
                } footer: {
                    Text("默认继续持有，沿用财富中的收益率和计息方式估算，工作中断不影响理财。赎回按全部本息一次转入现金，此后停止计息；这是情景假设，不会修改真实资产。")
                }
                Section {
                    Label("沿用已配置的日常开支与还款", systemImage: "list.bullet.rectangle")
                    Text("工作中断时，仅暂停已开启对应选项的开支；恢复工作后继续。房贷和信用卡还款照常计入。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let validation {
                    Section { Text(validation).font(.footnote).foregroundStyle(.red) }
                }
            }
            .neutralPageBackground()
            .environment(\.timeZone, ProfileRules.calendar.timeZone)
            .navigationTitle("调整情景").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用情景") { save() }.disabled(validation != nil)
                        .accessibilityIdentifier("scenario.apply")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { hideKeyboard() } }
            }
            .saveErrorAlert($errorMessage)
        }
    }
    private func moneyField(_ title: String, text: Binding<String>, id: String) -> some View {
        HStack {
            Text(title)
            TextField("待补充", text: text).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).monospacedDigit()
                .accessibilityLabel(title).accessibilityIdentifier(id)
            Text("元").foregroundStyle(.secondary)
        }
    }
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    private func save() {
        do { try ForecastScenarioStore.save(value, records: records, context: context); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}
