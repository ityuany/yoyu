import SwiftUI
import SwiftData

struct EquityGrantEditor: View {
    let holding: StockHolding
    let companyName: String
    var existing: EquityGrant?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var date: Date
    @State private var quantity: String
    @State private var entries: [EquityInstallmentDraft]
    @State private var mode = 0
    @State private var first = Date()
    @State private var count = 4
    @State private var months = 12
    @State private var perPeriod = ""
    @State private var error: String?
    init(holding: StockHolding, companyName: String, existing: EquityGrant? = nil) {
        self.holding = holding; self.companyName = companyName; self.existing = existing
        let parts = ProfileRules.calendar.dateComponents([.year, .month], from: Date())
        _name = State(initialValue: existing?.name ?? "\(parts.year!)年\(parts.month!)月授予")
        _date = State(initialValue: existing?.date ?? Date())
        _quantity = State(initialValue: ProfileRules.input(existing?.shares))
        _entries = State(initialValue: (existing?.installments ?? []).map { EquityInstallmentDraft(id: $0.id, date: $0.date, quantity: ProfileRules.input($0.shares), cancelled: $0.cancelled) })
    }
    private var draft: EquityGrant? {
        guard let shares = ProfileRules.scaledValue(quantity) else { return nil }
        var plans: [EquityInstallment] = []
        for entry in entries {
            guard let q = ProfileRules.scaledValue(entry.quantity) else { return nil }
            plans.append(EquityInstallment(id: entry.id, date: ProfileRules.calendar.startOfDay(for: entry.date), shares: q, cancelled: entry.cancelled))
        }
        return EquityGrant(id: existing?.id ?? UUID(), name: name, date: ProfileRules.calendar.startOfDay(for: date), shares: shares, installments: plans)
    }
    private var validation: String? {
        guard holding.grants != nil else { return "原有授予无法读取，请先检查。" }
        guard let draft else { return "请填写有效的授予和归属数量，最多两位小数。" }
        return EquityRules.error(draft)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("授予信息") {
                    Text(companyName).foregroundStyle(AppTheme.secondaryText)
                    TextField("批次名称", text: $name)
                    DatePicker("授予日期", selection: $date, displayedComponents: .date)
                    equityField("授予总量（股）", text: $quantity)
                }.listRowBackground(AppTheme.cardBackground)
                Section {
                    Picker("录入方式", selection: $mode) { Text("逐笔添加").tag(0); Text("按周期生成").tag(1); if existing == nil { Text("总量分 4 期").tag(2) } }.pickerStyle(.segmented)
                    if mode == 1 {
                        DatePicker("首次归属", selection: $first, displayedComponents: .date)
                        Picker("周期", selection: $months) { Text("每月").tag(1); Text("每季度").tag(3); Text("每年").tag(12) }
                        Stepper("生成 \(count) 期", value: $count, in: 1...120)
                        equityField("每期股数", text: $perPeriod)
                        Button("生成并追加到列表") {
                            guard let q = ProfileRules.scaledValue(perPeriod), q > 0 else { return }
                            entries += EquityRules.generate(first: first, count: count, months: months, shares: q).map { EquityInstallmentDraft(date: $0.date, quantity: ProfileRules.input($0.shares)) }
                            mode = 0
                        }.disabled(ProfileRules.scaledValue(perPeriod).map { $0 <= 0 } ?? true)
                    }
                    if mode == 2 {
                        EquityFourPeriodGenerator(quantity: quantity, grantDate: date, entries: $entries)
                    }
                    ForEach($entries) { $entry in
                        VStack(spacing: 12) {
                            DatePicker("归属日期", selection: $entry.date, displayedComponents: .date)
                            equityField("归属数量（股）", text: $entry.quantity)
                            Toggle("取消本期归属", isOn: $entry.cancelled)
                            if existing == nil {
                                Button("移除此期", role: .destructive) { entries.removeAll { $0.id == entry.id } }
                                    .buttonStyle(.borderless)
                            }
                        }.padding(.vertical, 8)
                    }
                    Button("添加一期", systemImage: "plus") { entries.append(EquityInstallmentDraft(date: max(date, Date()))) }
                } header: { Text("归属安排") } footer: { Text("各期数量不得超过授予总量。取消本期会保留记录；未安排的股数计为未归属，可稍后补全计划。") }.listRowBackground(AppTheme.cardBackground)
                if let draft, EquityRules.error(draft) == nil {
                    Section {
                        LabeledContent("已安排", value: "\(ProfileRules.input(draft.shares - EquityRules.unallocated(draft))) 股")
                        LabeledContent("待安排", value: "\(ProfileRules.input(EquityRules.unallocated(draft))) 股")
                    }.listRowBackground(AppTheme.cardBackground)
                }
                if let validation { Text(validation).foregroundStyle(AppTheme.secondaryText) }
            }.neutralPageBackground().navigationTitle(existing == nil ? "添加授予" : "编辑授予")
            .environment(\.timeZone, ProfileRules.calendar.timeZone)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save).disabled(validation != nil) }
            }.saveErrorAlert($error)
        }
    }
    private func save() {
        guard validation == nil, let draft, var grants = holding.grants else { return }
        if let index = grants.firstIndex(where: { $0.id == draft.id }) { grants[index] = draft } else { grants.append(draft) }
        holding.applyGrants(grants)
        guard StockRules.canSave(holding, on: Date()) else {
            context.rollback(); error = "修改后持仓不足以覆盖已记录的卖出／转出，或金额超出范围。"; return
        }
        holding.modifiedAt = Date()
        if let message = context.saveOrRollback() { error = message } else { dismiss() }
    }
}
