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
