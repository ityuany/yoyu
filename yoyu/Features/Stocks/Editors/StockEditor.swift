import SwiftUI
import SwiftData

private struct VestingDraft: Identifiable {
    var id: UUID = UUID()
    var date: Date = ProfileRules.calendar.date(byAdding: .year, value: 1, to: Date())!
    var shares: String = ""
}

struct StockEditor: View {
    let holding: StockHolding?
    var legacy: UserProfile?
    @Query private var jobs: [Employment]
    @Query private var holdings: [StockHolding]
    @State private var companyID = ""
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var currency: String
    @State private var price: String
    @State private var rate: String
    @State private var baseline: Date
    @State private var initial: String
    @State private var plans: [VestingDraft]
    @State private var error: String?

    init(holding: StockHolding?, legacy: UserProfile? = nil) {
        self.holding = holding
        self.legacy = legacy
        _name = State(initialValue: holding?.name ?? "")
        _currency = State(initialValue: holding?.currency ?? "CNY")
        _price = State(initialValue: ProfileRules.input(holding?.priceCents ?? legacy?.stockPriceCents))
        _rate = State(initialValue: holding.map { String($0.yuanRate) } ?? "1")
        _baseline = State(initialValue: holding?.baselineDate ?? Date())
        _initial = State(initialValue: (holding == nil && legacy == nil) ? "0" : ProfileRules.input(holding?.initialSharesHundredths ?? legacy?.stockSharesHundredths))
        _plans = State(initialValue: (holding?.vestings ?? []).map { VestingDraft(id: $0.id, date: $0.date, shares: ProfileRules.input($0.sharesHundredths)) })
    }

    private var parsedRate: Double? {
        if currency == "CNY" { return 1 }
        guard rate.range(of: #"^[0-9]+(\.[0-9]{1,4})?$"#, options: .regularExpression) != nil,
              let value = Double(rate), value > 0, value <= 100_000 else { return nil }
        return value
    }
    private var parsedPlans: [StockVesting]? {
        var result: [StockVesting] = []
        for plan in plans {
            guard let shares = ProfileRules.scaledValue(plan.shares), shares > 0 else { return nil }
            result.append(StockVesting(id: plan.id, date: ProfileRules.calendar.startOfDay(for: plan.date), sharesHundredths: shares))
        }
        return result
    }
    private var validation: String? {
        if holding != nil && holding?.vestings == nil { return "原有计划无法读取，请先检查数据，避免覆盖。" }
        if legacy != nil {
            guard let legacy, StockRules.needsLegacyReview(holdings, profile: legacy) else { return "旧记录已处理，请返回股票列表。" }
            if companyID.isEmpty { return "请选择所属公司。" }
            if holdings.contains(where: { $0.employmentID == companyID }) { return "该公司已有股票，请返回核对流程，避免重复录入。" }
        }
        if legacy == nil && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请填写股票或公司名称。" }
        guard ProfileRules.scaledValue(price) != nil, ProfileRules.scaledValue(initial) != nil else { return "价格与持股数量请输入非负数，最多两位小数。" }
        guard parsedRate != nil else { return "请填写有效人民币汇率，最多四位小数。" }
        guard let entries = parsedPlans else { return "每笔归属数量须大于 0，最多两位小数。" }
        let base = ProfileRules.calendar.startOfDay(for: baseline)
        if base > ProfileRules.calendar.startOfDay(for: Date()) { return "持股基准日不能晚于今天。" }
        if entries.contains(where: { $0.date <= base }) { return "归属计划须晚于基准日；此前已归属部分请计入基准持股。" }
        if preview == nil { return "股数或参考价值超出支持范围，请检查。" }
        return nil
    }
    private func draftHolding() -> StockHolding? {
        guard let quantity = ProfileRules.scaledValue(initial), let price = ProfileRules.scaledValue(price),
              let rate = parsedRate, let entries = parsedPlans else { return nil }
        let item = StockHolding()
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.currency = currency
        item.priceCents = price
        item.yuanRate = rate
        item.baselineDate = ProfileRules.calendar.startOfDay(for: baseline)
        item.initialSharesHundredths = quantity
        item.applyVestings(entries)
        return item
    }
    private var preview: StockRules.Value? {
        guard let quantity = ProfileRules.scaledValue(initial), let price = ProfileRules.scaledValue(price),
              let plans = parsedPlans, let rate = parsedRate,
              let value = StockRules.value(initial: quantity, plans: plans, price: price, on: Date()),
              Decimal(value.total) * Decimal(rate) <= Decimal(ProfileRules.maximumMoneyCents) else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("股票信息") {
                    if legacy != nil {
                        Picker("所属公司", selection: $companyID) {
                            Text("请选择").tag("")
                            ForEach(CareerRules.employments(jobs).filter { job in !holdings.contains { $0.employmentID == job.id } }) { job in
                                Text(job.displayName).tag(job.id)
                            }
                        }
                        Text("仅列出尚未建立股票记录的公司。若公司不在履历中，请先补充企业履历。")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        TextField("股票／公司名称", text: $name)
                    }
                    Picker("币种", selection: $currency) {
                        Text("人民币 CNY").tag("CNY")
                        Text("港币 HKD").tag("HKD")
                        Text("美元 USD").tag("USD")
                    }
                    field("每股价格", value: $price)
                    if currency != "CNY" { field("1 \(currency) 折合人民币", value: $rate) }
                }
                Section {
                    DatePicker("持股基准日", selection: $baseline, in: ...Date(), displayedComponents: .date)
                    field("已归属持股（股）", value: $initial)
                } header: { Text("已归属持股") } footer: {
                    Text("填写基准日已归属且仍持有的股数；下面的归属计划在此基础上增加，不要重复计入。")
                }
                Section {
                    ForEach($plans) { $plan in
                        VStack(spacing: 12) {
                            DatePicker("归属日期", selection: $plan.date, displayedComponents: .date)
                            field("归属数量（股）", value: $plan.shares)
                            Button("移除此笔计划", role: .destructive) { plans.removeAll { $0.id == plan.id } }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }.padding(.vertical, 6)
                    }
                    Button("添加归属计划", systemImage: "plus") { plans.append(VestingDraft()) }
                } header: { Text("归属计划") } footer: {
                    Text("每笔填写日期与股数，到期后自动归为已归属。可编辑日期和数量，或移除取消的计划。")
                }
                Section("参考价值 · \(currency)") {
                    LabeledContent("已归属", value: StockRules.money(preview?.vested, currency: currency))
                    LabeledContent("未归属", value: StockRules.money(preview?.unvested, currency: currency))
                    LabeledContent("总股票价值", value: StockRules.money(preview?.total, currency: currency))
                }
                if let legacyValue = legacy?.stockValueCents {
                    Section { Text("原股票金额 \(ProfileRules.money(legacyValue))；保存后按本次填写的股数与价格计算，原始数据保留。") }
                }
                if let validation { Section { Text(validation).foregroundStyle(.secondary) } }
            }.neutralPageBackground()
            .environment(\.timeZone, ProfileRules.calendar.timeZone)
            .navigationTitle(legacy != nil ? "迁入旧持股" : holding == nil ? "添加股票" : "编辑股票")
            .onChange(of: currency) { _, new in rate = new == "CNY" ? "1" : "" }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save).disabled(validation != nil) }
            }
            .saveErrorAlert($error)
        }
    }
    private func field(_ title: String, value: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField("请填写", text: value).multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad).accessibilityLabel(title)
        }
    }
    private func save() {
        guard validation == nil, let draft = draftHolding() else { return }
        let item = holding ?? StockHolding()
        if holding == nil {
            if let legacy { item.id = "legacy-stock-\(legacy.createdAt.timeIntervalSince1970)" }
            context.insert(item)
        }
        if item.priceCents != draft.priceCents || item.currency != draft.currency || holding == nil { item.priceUpdatedAt = Date() }
        item.name = legacy != nil ? (jobs.first { $0.id == companyID }?.displayName ?? draft.name) : draft.name
        if legacy != nil { item.employmentID = companyID }
        item.currency = draft.currency
        item.priceCents = draft.priceCents
        item.yuanRate = draft.yuanRate
        item.baselineDate = draft.baselineDate
        item.initialSharesHundredths = draft.initialSharesHundredths
        item.applyGrants(draft.grants ?? [])
        item.modifiedAt = Date()
        legacy?.stockMigrated = true
        if let message = context.saveOrRollback() { error = message } else { dismiss() }
    }
}
