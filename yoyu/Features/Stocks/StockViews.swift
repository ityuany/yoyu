import SwiftUI
import SwiftData

struct StockPortfolioView: View {
    @Query private var jobs: [Employment]
    @Query private var holdings: [StockHolding]
    @Query private var profiles: [UserProfile]
    @Environment(CareerClock.self) private var clock
    @State private var adding = false
    @State private var pendingCompany: String?
    @State private var selectedCompany: String?
    @State private var reviewingLegacy = false
    @State private var selectedDay: Date?
    @State private var showUnallocated = false
    private var profile: UserProfile? { profiles.max { $0.updatedAt(for: .wealth) < $1.updatedAt(for: .wealth) } }
    var body: some View {
        List {
            Section {
                if !holdings.isEmpty && StockRules.needsLegacyReview(holdings, profile: profile) {
                    Text("请先核对旧股票记录，再查看汇总价值。").font(.caption).foregroundStyle(.secondary)
                }
                if holdings.contains(where: { !$0.priceIsConfigured }) {
                    Text("部分公司待设置股价，汇总金额待补全。").font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("已归属价值", value: ProfileRules.money(StockRules.portfolio(holdings, profile: profile, on: clock.now)))
                LabeledContent("未归属价值", value: ProfileRules.money(StockRules.portfolio(holdings, profile: profile, on: clock.now, unvested: true)))
            } header: { Text("人民币参考价值") } footer: {
                Text("当前财富仅计入已归属部分。未来归属按当前手动股价估算；已归属不代表可以立即出售。")
            }
            if !holdings.isEmpty {
                Section("公司") {
                    ForEach(StockRules.holdings(holdings)) { holding in
                        NavigationLink(value: WealthDestination.holding(holding.id)) {
                            Text(jobs.first { $0.id == holding.employmentID }?.displayName ?? holding.name)
                        }
                    }
                }
            }
            if !holdings.isEmpty {
                Section("未来股票归属") {
                    VestingTimelineSections(holdings: holdings, now: clock.now, selectedDay: $selectedDay, showUnallocated: $showUnallocated)
                }
            }
            if let profile, StockRules.needsLegacyReview(holdings, profile: profile) {
                Section {
                    LabeledContent("原有股票金额", value: ProfileRules.money(profile.stockValueCents))
                    Button("核对旧股票记录") { reviewingLegacy = true }
                } header: { Text("一次性核对") } footer: {
                    Text("旧记录尚未关联公司。请核对是否已包含在现有持股中；新旧记录同时存在时，汇总暂不计算，避免重复。")
                }
            }
            if holdings.isEmpty && StockRules.legacy(profile) == nil {
                ContentUnavailableView("记录你的股票激励", systemImage: "chart.line.uptrend.xyaxis", description: Text("选择任职公司，填写授予批次和归属计划。股价在公司详情统一设置。"))
            }
            Section { Button("添加公司股票", systemImage: "plus") { adding = true } }
        }.neutralPageBackground()
        .listSectionSpacing(16)
        .navigationDestination(item: $selectedDay) { date in VestingSourcesView(date: date) }
        .navigationDestination(isPresented: $showUnallocated) { VestingSourcesView(date: nil) }
        .navigationTitle("股票")
        .toolbar(.visible, for: .navigationBar)

        .sheet(isPresented: $adding, onDismiss: {
            if let pendingCompany { selectedCompany = pendingCompany; self.pendingCompany = nil }
        }) {
            EquityPriceEditor(holding: nil) { companyID in pendingCompany = companyID }
        }
        .navigationDestination(item: $selectedCompany) { id in
            if let job = CareerRules.employments(jobs).first(where: { $0.id == id }) {
                if let holding = StockRules.holdings(holdings).first(where: { $0.employmentID == job.id }) {
                    EquityOverview(holding: holding, companyName: job.displayName)
                }
            }
        }
        .sheet(isPresented: $reviewingLegacy) {
            if let profile { LegacyStockReview(profile: profile) }
        }
    }
}

private struct LegacyStockReview: View {
    let profile: UserProfile
    @Query private var holdings: [StockHolding]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CareerClock.self) private var clock
    @Environment(AppNavigation.self) private var navigation
    @State private var selectedID = ""
    @State private var confirming = false
    @State private var importing = false
    @State private var error: String?

    private var selected: StockHolding? { StockRules.holdings(holdings).first { $0.id == selectedID } }

    var body: some View {
        NavigationStack {
            Form {
                Section("旧记录") {
                    LabeledContent("人民币参考价值", value: ProfileRules.money(profile.stockValueCents))
                    if let shares = profile.stockSharesHundredths {
                        LabeledContent("已归属持股", value: "\(ProfileRules.input(shares)) 股")
                    }
                    Text("请先确认这份旧记录是否已包含在现有公司持股中。旧数据会保留备查，核对完成后不再单独计入。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !holdings.isEmpty {
                    Section {
                        Picker("对应股票", selection: $selectedID) {
                            Text("请选择").tag("")
                            ForEach(StockRules.holdings(holdings)) { holding in
                                Text(holding.name).tag(holding.id)
                            }
                        }
                        if let selected {
                            let balance = StockRules.balance(selected, on: clock.now)
                            LabeledContent("现有已归属持股", value: balance.map { "\(ProfileRules.input($0.vestedShares)) 股" } ?? "待补全")
                            LabeledContent("现有未归属", value: balance.map { "\(ProfileRules.input($0.unvestedShares)) 股" } ?? "待补全")
                            Button("查看或补全这份公司记录") {
                                navigation.openStocks(holdingID: selected.id)
                                dismiss()
                            }
                            Button("旧记录已全部包含，完成核对") { confirming = true }
                                .disabled(balance == nil)
                        }
                    } header: { Text("与现有持股核对") } footer: {
                        Text("如果只录入了一部分，请先补全公司记录的期初持股或授予计划，再回来完成核对。不会自动相加或覆盖持股。")
                    }
                }
                Section {
                    Button("这是尚未录入的另一份持股") { importing = true }
                } footer: { Text("将旧持股迁入公司股票。已有股票记录的公司请使用上面的核对流程。") }
            }.neutralPageBackground()
            .navigationTitle("核对旧股票记录")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("稍后处理") { dismiss() } } }
            .confirmationDialog("确认旧记录已全部包含？", isPresented: $confirming, titleVisibility: .visible) {
                Button("确认，使用现有公司记录") { resolve() }
            } message: {
                Text("核对对象：\(selected?.name ?? "")。完成后只统计公司记录，旧金额不再单独计入；原始资料保留。")
            }
            .sheet(isPresented: $importing, onDismiss: {
                if !StockRules.needsLegacyReview(holdings, profile: profile) { dismiss() }
            }) { StockEditor(holding: nil, legacy: profile) }
            .saveErrorAlert($error)
        }
    }

    private func resolve() {
        guard let selected, StockRules.balance(selected, on: clock.now) != nil,
              StockRules.needsLegacyReview(holdings, profile: profile) else { return }
        profile.stockMigrated = true
        if let message = context.saveOrRollback() { error = message } else { dismiss() }
    }
}

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
        item.vestingData = try? JSONEncoder().encode(entries)
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
        item.vestingData = draft.vestingData
        item.modifiedAt = Date()
        legacy?.stockMigrated = true
        if let message = context.saveOrRollback() { error = message } else { dismiss() }
    }
}
