import SwiftUI
import SwiftData

struct RunwayEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CareerClock.self) private var clock
    let records: [RunwaySettings]
    @State var draft: RunwayPlan
    @State private var salary = ""
    @State private var flexible = ""
    @State private var error: String?
    private var value: RunwayPlan {
        var p = draft
        p.salary = ProfileRules.scaledValue(salary)
        p.flexible = ProfileRules.scaledValue(flexible) ?? -1
        return p
    }
    private var validation: String? { RunwayEngine.validation(value, today: clock.now) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("情景模式", selection: $draft.mode) {
                        ForEach(RunwayMode.allCases) { Text($0.title).tag($0) }
                    }.accessibilityIdentifier("runway.mode")
                    if draft.mode != .employed {
                        if draft.lossDate != nil {
                            DatePicker("失业时间", selection: Binding(get: { draft.lossDate! }, set: { draft.lossDate = $0 }), in: RunwayEngine.day(clock.now)..., displayedComponents: .date)
                                .accessibilityIdentifier("runway.lossDate")
                        } else {
                            Button("设置失业时间（必填）") { draft.lossDate = RunwayEngine.day(clock.now) }
                                .accessibilityIdentifier("runway.setLoss")
                        }
                    }
                    if draft.mode == .temporary {
                        if draft.returnDate != nil {
                            DatePicker("就业时间", selection: Binding(get: { draft.returnDate! }, set: { draft.returnDate = $0 }), in: RunwayEngine.day(clock.now)..., displayedComponents: .date)
                        } else {
                            Button("设置就业时间（必填）") { draft.returnDate = ProfileRules.calendar.date(byAdding: .month, value: 6, to: draft.lossDate ?? clock.now) }
                                .accessibilityIdentifier("runway.setReturn")
                        }
                    }
                } header: { Text("工作安排") } footer: {
                    Text(draft.mode == .employed ? "沿用当前公司的薪资和发薪日，持续计入工资。" : "从失业日期开始计算生存时长，失业前的收支用于推算起始本金。")
                }
                if draft.mode == .temporary {
                    Section("重新就业") {
                        moneyField("就业薪资", text: $salary)
                        payday("每月发薪日", selection: $draft.payday)
                    }
                }
                if draft.mode != .employed {
                    Section {
                        moneyField("灵活收入", text: $flexible)
                        payday("每月到账日", selection: $draft.flexibleDay)
                    } header: { Text("灵活收入") } footer: {
                        Text("失业或不再就业期间，通过其他方式赚取的收入。按税前月薪填写，没有收入填 0。")
                    }
                }
                Section {
                    Text("现金不足时依次使用股票和理财，理财按需赎回，剩余金额继续计息。无需配置赎回计划。")
                        .foregroundStyle(.secondary)
                }
                if let validation { Section { Text(validation).foregroundStyle(.secondary) } }
            }
            .neutralPageBackground()
            .environment(\.calendar, ProfileRules.calendar)
            .environment(\.timeZone, ProfileRules.calendar.timeZone)
            .navigationTitle("调整情景")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try RunwayStore.save(value, records: records, context: context); dismiss() }
                        catch { self.error = "保存失败，请重试。" }
                    }.disabled(validation != nil).accessibilityIdentifier("runway.save")
                }
            }
            .onAppear {
                salary = ProfileRules.input(draft.salary)
                flexible = ProfileRules.input(draft.flexible)
            }
            .onChange(of: draft.mode) { _, next in
                draft = RunwayStore.record(records, mode: next)?.plan ?? RunwayPlan(mode: next)
                salary = ProfileRules.input(draft.salary)
                flexible = ProfileRules.input(draft.flexible)
            }
            .saveErrorAlert($error)
        }
    }
    private func moneyField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("税前金额", text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .accessibilityLabel(title)
            Text("元/月").foregroundStyle(.secondary)
        }
    }
    private func payday(_ title: String, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) { ForEach(1...31, id: \.self) { Text("每月 \($0) 号").tag($0) } }
    }
}
