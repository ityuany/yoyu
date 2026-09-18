import SwiftUI
import SwiftData

private struct InstallmentDraft: Identifiable {
    var id = UUID()
    var date = Date()
    var quantity = ""
    var cancelled = false
}
struct EquityGrantEditor: View {
    let holding: StockHolding
    let companyName: String
    var existing: EquityGrant?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var date: Date
    @State private var quantity: String
    @State private var entries: [InstallmentDraft]
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
        _entries = State(initialValue: (existing?.installments ?? []).map { InstallmentDraft(id: $0.id, date: $0.date, quantity: ProfileRules.input($0.shares), cancelled: $0.cancelled) })
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
                    Text(companyName).foregroundStyle(.secondary)
                    TextField("批次名称", text: $name)
                    DatePicker("授予日期", selection: $date, displayedComponents: .date)
                    equityField("授予总量（股）", text: $quantity)
                }
                Section {
                    Picker("录入方式", selection: $mode) { Text("逐笔添加").tag(0); Text("按周期生成").tag(1) }.pickerStyle(.segmented)
                    if mode == 1 {
                        DatePicker("首次归属", selection: $first, displayedComponents: .date)
                        Picker("周期", selection: $months) { Text("每月").tag(1); Text("每季度").tag(3); Text("每年").tag(12) }
                        Stepper("生成 \(count) 期", value: $count, in: 1...120)
                        equityField("每期股数", text: $perPeriod)
                        Button("生成并追加到列表") {
                            guard let q = ProfileRules.scaledValue(perPeriod), q > 0 else { return }
                            entries += EquityRules.generate(first: first, count: count, months: months, shares: q).map { InstallmentDraft(date: $0.date, quantity: ProfileRules.input($0.shares)) }
                            mode = 0
                        }.disabled(ProfileRules.scaledValue(perPeriod).map { $0 <= 0 } ?? true)
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
                    Button("添加一期", systemImage: "plus") { entries.append(InstallmentDraft(date: max(date, Date()))) }
                } header: { Text("归属安排") } footer: { Text("各期数量不得超过授予总量。取消本期会保留记录；未安排的股数计为未归属，可稍后补全计划。") }
                if let draft, EquityRules.error(draft) == nil {
                    Section {
                        LabeledContent("已安排", value: "\(ProfileRules.input(draft.shares - EquityRules.unallocated(draft))) 股")
                        LabeledContent("待安排", value: "\(ProfileRules.input(EquityRules.unallocated(draft))) 股")
                    }
                }
                if let validation { Text(validation).foregroundStyle(.secondary) }
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
        do {
            holding.grantData = try JSONEncoder().encode(grants)
            guard StockRules.canSave(holding, on: Date()) else {
                context.rollback(); error = "修改后持仓不足以覆盖已记录的卖出／转出，或金额超出范围。"; return
            }
            holding.modifiedAt = Date()
            if let message = context.saveOrRollback() { error = message } else { dismiss() }
        } catch { context.rollback(); self.error = error.localizedDescription }
    }
}

struct EquityPriceEditor: View {
    var holding: StockHolding?
    var job: Employment?
    var onSaved: ((String) -> Void)?
    @Query private var jobs: [Employment]
    @Query private var holdings: [StockHolding]
    @State private var selectedCompany: String
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var price: String
    @State private var currency: String
    @State private var rate: String
    @State private var grantName = "首次授予"
    @State private var grantDate = Date()
    @State private var grantQuantity = ""
    @State private var grantEntries: [InstallmentDraft] = []
    @State private var error: String?
    init(holding: StockHolding?, job: Employment? = nil, onSaved: ((String) -> Void)? = nil) {
        self.holding = holding; self.job = job; self.onSaved = onSaved
        _selectedCompany = State(initialValue: job?.id ?? "")
        _price = State(initialValue: ProfileRules.input(holding?.priceIsConfigured == true ? holding?.priceCents : nil))
        _currency = State(initialValue: holding?.currency ?? "CNY")
        _rate = State(initialValue: String(holding?.yuanRate ?? 1))
    }
    private var parsedRate: Double? {
        if currency == "CNY" { return 1 }
        guard rate.range(of: #"^[0-9]+(\.[0-9]{1,4})?$"#, options: .regularExpression) != nil,
              let v = Double(rate), v > 0, v <= 100_000 else { return nil }
        return v
    }
    private var firstGrant: EquityGrant? {
        guard let quantity = ProfileRules.scaledValue(grantQuantity) else { return nil }
        var plans: [EquityInstallment] = []
        for entry in grantEntries {
            guard let shares = ProfileRules.scaledValue(entry.quantity) else { return nil }
            plans.append(EquityInstallment(id: entry.id, date: ProfileRules.calendar.startOfDay(for: entry.date), shares: shares))
        }
        return EquityGrant(name: grantName, date: ProfileRules.calendar.startOfDay(for: grantDate), shares: quantity, installments: plans)
    }
    private var grantError: String? {
        guard holding == nil else { return nil }
        guard let firstGrant else { return "填写授予总量，再添加各期归属日期与数量。" }
        return EquityRules.error(firstGrant)
    }
    var body: some View {
        NavigationStack {
            Form {
                if holding == nil {
                    if let job { LabeledContent("任职公司", value: job.displayName) }
                    else {
                        Picker("任职公司", selection: $selectedCompany) {
                            Text("请选择公司").tag("")
                            ForEach(CareerRules.employments(jobs).filter { company in !holdings.contains { $0.employmentID == company.id } }) { company in
                                Text(company.displayName).tag(company.id)
                            }
                        }
                        if jobs.isEmpty {
                            NavigationLink("添加企业履历") { CareerView(destination: .history) }
                        }
                    }
                }
                if holding != nil {
                Picker("币种", selection: $currency) { Text("人民币").tag("CNY"); Text("港币").tag("HKD"); Text("美元").tag("USD") }
                equityField("每股价格", text: $price)
                if currency != "CNY" { equityField("1 \(currency) 折合人民币", text: $rate) }
                }
                if holding == nil {
                    Section("本次授予") {
                        TextField("批次名称", text: $grantName)
                        DatePicker("授予日期", selection: $grantDate, displayedComponents: .date)
                        equityField("授予总量（股）", text: $grantQuantity)
                    }
                    Section {
                        ForEach($grantEntries) { $entry in
                            VStack(spacing: 12) {
                                DatePicker("归属日期", selection: $entry.date, displayedComponents: .date)
                                equityField("归属数量（股）", text: $entry.quantity)
                                Button("移除此期", role: .destructive) { grantEntries.removeAll { $0.id == entry.id } }
                                    .buttonStyle(.borderless)
                            }.padding(.vertical, 6)
                        }
                        Button("添加一期归属", systemImage: "plus") {
                            grantEntries.append(InstallmentDraft(date: max(grantDate, Date())))
                        }
                        if let firstGrant, EquityRules.error(firstGrant) == nil {
                            LabeledContent("待安排", value: "\(ProfileRules.input(EquityRules.unallocated(firstGrant))) 股")
                        }
                    } header: { Text("归属计划") } footer: {
                        Text("按期填写日期与数量。未安排部分计入未归属，保存后可继续添加批次或按周期生成计划。")
                    }
                    if let grantError { Text(grantError).font(.caption).foregroundStyle(.secondary) }
                } else {
                    Text("所有授予批次共用此价格，参考价值一起更新。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.neutralPageBackground().navigationTitle(holding == nil ? "添加授予" : "设置股价")
            .environment(\.timeZone, ProfileRules.calendar.timeZone)
            .onChange(of: currency) { _, v in rate = v == "CNY" ? "1" : "" }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") {
                    let item = holding ?? StockHolding()
                    if holding == nil {
                        guard let job = job ?? CareerRules.employments(jobs).first(where: { $0.id == selectedCompany }) else { return }
                        if holdings.contains(where: { $0.employmentID == job.id }) {
                            error = "该公司已有股票激励，请从列表进入并添加授予。草稿尚未保存。"; return
                        }
                        guard let firstGrant, EquityRules.error(firstGrant) == nil,
                              let data = try? JSONEncoder().encode([firstGrant]) else { return }
                        item.priceIsConfigured = false
                        item.grantData = data
                        item.id = "company-stock-\(job.id)"; item.employmentID = job.id; item.name = job.displayName
                        context.insert(item)
                    }
                    if holding != nil {
                        guard let p = ProfileRules.scaledValue(price), let r = parsedRate else { return }
                        item.priceCents = p; item.currency = currency; item.yuanRate = r
                        item.priceIsConfigured = true; item.priceUpdatedAt = Date()
                    }
                    item.modifiedAt = Date()
                    guard StockRules.canSave(item, on: Date()) else {
                        context.rollback(); error = "参考价值超出支持范围。"; return
                    }
                    if let message = context.saveOrRollback() { error = message } else { onSaved?(item.employmentID); dismiss() }
                }.disabled(holding == nil ? (selectedCompany.isEmpty || grantError != nil) : (ProfileRules.scaledValue(price) == nil || parsedRate == nil)) }
            }.saveErrorAlert($error)
        }
    }
}

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
                    do {
                        holding.initialSharesHundredths = initial
                        holding.disposalData = try JSONEncoder().encode(changes)
                        guard StockRules.canSave(holding, on: Date()) else { context.rollback(); error = "减少数量不能超过已归属持仓。"; return }
                        holding.modifiedAt = Date()
                        if let message = context.saveOrRollback() { error = message } else { dismiss() }
                    } catch { context.rollback(); self.error = error.localizedDescription }
                }.disabled(ProfileRules.scaledValue(initial) == nil) }
            }.saveErrorAlert($error)
        }
    }
}
