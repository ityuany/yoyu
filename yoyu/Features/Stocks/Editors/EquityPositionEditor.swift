import SwiftUI
import SwiftData

struct EquityPositionEditor: View {
    let holding: StockHolding
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var initial: String
    @State private var reduction = ""
    @State private var error: String?
    init(holding: StockHolding) { self.holding = holding; _initial = State(initialValue: ProfileRules.input(holding.initialSharesHundredths)) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    equityField("期初持股（股）", text: $initial)
                } footer: { Text("只填写未包含在授予批次中的已归属持股。补录历史授予时，请同步扣除对应期初数量，避免重复。") }
                Section {
                    equityField("本次卖出／转出（股）", text: $reduction)
                } footer: { Text("填写本次减少的持股数量，按今天记录。不会修改授予和归属历史。无需减少时留空。") }
                Section("持仓减少记录") {
                    ForEach(holding.disposals ?? []) { disposal in
                        LabeledContent(CareerRules.dateLabel(disposal.date), value: "−\(ProfileRules.input(disposal.shares)) 股")
                    }
                }
            }.neutralPageBackground().navigationTitle("持仓调整")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") {
                    guard let initial = ProfileRules.scaledValue(initial), var changes = holding.disposals else { return }
                    if !reduction.isEmpty {
                        guard let q = ProfileRules.scaledValue(reduction), q > 0 else { error = "请填写有效的减少数量。"; return }
                        changes.append(EquityDisposal(date: ProfileRules.calendar.startOfDay(for: Date()), shares: q))
                    }
                    holding.initialSharesHundredths = initial
                    holding.applyDisposals(changes)
                    guard StockRules.canSave(holding, on: Date()) else { context.rollback(); error = "减少数量不能超过已归属持仓。"; return }
                    holding.modifiedAt = Date()
                    if let message = context.saveOrRollback() { error = message } else { dismiss() }
                }.disabled(ProfileRules.scaledValue(initial) == nil) }
            }.saveErrorAlert($error)
        }
    }
}
