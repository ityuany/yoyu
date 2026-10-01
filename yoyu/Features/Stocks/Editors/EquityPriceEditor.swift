import SwiftUI
import SwiftData

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
    @State private var grantMode = 0
    @State private var grantEntries: [EquityInstallmentDraft] = []
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
                    }.listRowBackground(AppTheme.cardBackground)
                    Section {
                        Picker("录入方式", selection: $grantMode) {
                            Text("逐笔添加").tag(0)
                            Text("总量分 4 期").tag(1)
                        }.pickerStyle(.segmented)
                        if grantMode == 1 {
                            EquityFourPeriodGenerator(quantity: grantQuantity, grantDate: grantDate, entries: $grantEntries)
                        }
                        ForEach($grantEntries) { $entry in
                            VStack(spacing: 12) {
                                DatePicker("归属日期", selection: $entry.date, displayedComponents: .date)
                                equityField("归属数量（股）", text: $entry.quantity)
                                Button("移除此期", role: .destructive) { grantEntries.removeAll { $0.id == entry.id } }
                                    .buttonStyle(.borderless)
                            }.padding(.vertical, 6)
                        }
                        Button("添加一期归属", systemImage: "plus") {
                            grantEntries.append(EquityInstallmentDraft(date: max(grantDate, Date())))
                        }
                        if let firstGrant, EquityRules.error(firstGrant) == nil {
                            LabeledContent("待安排", value: "\(ProfileRules.input(EquityRules.unallocated(firstGrant))) 股")
                        }
                    } header: { Text("归属计划") } footer: {
                        Text("可逐笔填写，或按总量生成 4 期后调整日期与数量。修改总量后请重新生成；未安排部分计入未归属。")
                    }.listRowBackground(AppTheme.cardBackground)
                    if let grantError { Text(grantError).font(.caption).foregroundStyle(AppTheme.secondaryText) }
                } else {
                    Text("所有授予批次共用此价格，参考价值一起更新。")
                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
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
                        guard let firstGrant, EquityRules.error(firstGrant) == nil else { return }
                        item.priceIsConfigured = false
                        item.applyGrants([firstGrant])
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
