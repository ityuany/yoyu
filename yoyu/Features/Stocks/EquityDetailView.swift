import SwiftUI
import SwiftData

/// Employment is a read-only summary; all edits live in the Wealth navigation stack.
struct CompanyStockSummary: View {
    let job: Employment
    @Query private var holdings: [StockHolding]
    @Environment(CareerClock.self) private var clock
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        Section {
            if let holding = StockRules.holdings(holdings).first(where: { $0.employmentID == job.id }) {
                let balance = StockRules.balance(holding, on: clock.now)
                LabeledContent("已归属持股", value: balance.map { "\(ProfileRules.input($0.vestedShares)) 股" } ?? "待补全")
                LabeledContent("未归属", value: balance.map { "\(ProfileRules.input($0.unvestedShares)) 股" } ?? "待补全")
                Button("前往财富查看股票") { navigation.openStocks(holdingID: holding.id) }
            } else {
                Text("尚未关联股票记录").foregroundStyle(.secondary)
                Button("前往财富管理股票") { navigation.openStocks() }
            }
        } header: { Text("股票激励") } footer: {
            Text("授予、归属计划和股价统一在「财富 → 股票」管理。")
        }
    }
}

struct EquityOverview: View {
    let holding: StockHolding
    var companyName: String
    @Environment(CareerClock.self) private var clock
    @State private var price = false
    @State private var adding = false
    @State private var position = false
    private var grants: [EquityGrant] { (holding.grants ?? []).sorted { $0.date > $1.date } }
    private var next: [(EquityGrant, EquityInstallment)] {
        let future = grants.flatMap { g in g.installments.filter { !$0.cancelled && $0.date > ProfileRules.calendar.startOfDay(for: clock.now) }.map { (g, $0) } }
        guard let day = future.map({ $0.1.date }).min() else { return [] }
        return future.filter { $0.1.date == day }
    }
    var body: some View {
        List {
            Section {
                let value = StockRules.value(holding, on: clock.now)
                let balance = StockRules.balance(holding, on: clock.now)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        summaryAmount("已归属价值", cents: value?.vested, shares: balance?.vestedShares)
                        Divider()
                        summaryAmount("未归属参考价值", cents: value?.unvested, shares: balance?.unvestedShares)
                    }.fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 16) {
                        summaryAmount("已归属价值", cents: value?.vested, shares: balance?.vestedShares)
                        summaryAmount("未归属参考价值", cents: value?.unvested, shares: balance?.unvestedShares)
                    }
                }.padding(.vertical, 8)
                LabeledContent("总参考价值", value: value.map { StockRules.money($0.total, currency: holding.currency) } ?? (holding.priceIsConfigured ? "待补全" : "待设置股价"))
            }
            Section {
                HStack {
                    Text("股价").font(.headline)
                    Spacer()
                    Button(holding.priceIsConfigured ? "更新股价" : "设置股价") { price = true }
                        .buttonStyle(.borderless)
                }
                LabeledContent("每股价格", value: holding.priceIsConfigured ? StockRules.money(holding.priceCents, currency: holding.currency) : "待设置股价")
            } footer: { Text("本公司所有授予批次共用此价格。") }
            Section {
                ForEach(grants) { grant in
                    NavigationLink {
                        EquityGrantDetail(holding: holding, grantID: grant.id, companyName: companyName)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .center) {
                                Text(grant.name).font(.headline)
                            }
                            Text("授予 \(ProfileRules.input(grant.shares)) 股 · 已归属 \(ProfileRules.input(EquityRules.vested(grant, on: clock.now))) 股")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if EquityRules.unallocated(grant) > 0 {
                                Text("\(ProfileRules.input(EquityRules.unallocated(grant))) 股计划待补全").font(.caption).foregroundStyle(.secondary)
                            }
                        }.foregroundStyle(.primary)
                    }.buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Text("授予记录")
                    Spacer()
                    Button("添加授予") { adding = true }.buttonStyle(.borderless)
                }
            }
            if let day = next.first?.1.date {
                Section {
                    NavigationLink { nextInstallments } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("下一次归属").font(.headline)
                            LabeledContent(CareerRules.dateLabel(day), value: "\(ProfileRules.input(next.reduce(0) { $0 + $1.1.shares })) 股")
                            Text("来自 \(Set(next.map { $0.0.id }).count) 笔授予").font(.caption).foregroundStyle(.secondary)
                        }.foregroundStyle(.primary)
                    }.buttonStyle(.plain)
                }
            }
            Section {
                Button("期初持股与持仓调整") { position = true }
            } footer: { Text("按计划到期归属，未归属数量包括计划待补全部分。参考价值按手动股价计算，不含税费。") }
        }.neutralPageBackground()
        .navigationTitle(holding.name)
        .sheet(isPresented: $price) { EquityPriceEditor(holding: holding) }
        .sheet(isPresented: $adding) { EquityGrantEditor(holding: holding, companyName: companyName) }
        .sheet(isPresented: $position) { EquityPositionEditor(holding: holding) }
    }

    private var nextInstallments: some View {
            List {
                ForEach(next, id: \.1.id) { grant, installment in
                    NavigationLink { EquityGrantDetail(holding: holding, grantID: grant.id, companyName: companyName) } label: {
                        LabeledContent(grant.name, value: "\(ProfileRules.input(installment.shares)) 股")
                    }
                }
            }.neutralPageBackground().navigationTitle("下一次归属")
    }
    private func summaryAmount(_ title: String, cents: Int64?, shares: Int64?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(cents.map { StockRules.money($0, currency: holding.currency) } ?? (holding.priceIsConfigured ? "待补全" : "待设置股价"))
                .font(.headline).monospacedDigit()
            if let shares { Text("\(ProfileRules.input(shares)) 股").font(.caption).foregroundStyle(.secondary) }
        }
    }

}

struct EquityGrantDetail: View {
    let holding: StockHolding
    let grantID: UUID
    let companyName: String
    @Environment(CareerClock.self) private var clock
    @State private var editing = false
    private var grant: EquityGrant? { holding.grants?.first { $0.id == grantID } }
    var body: some View {
        List {
            if let grant {
                Section("授予信息") {
                    Text(companyName).foregroundStyle(.secondary)
                    LabeledContent("授予日期", value: CareerRules.dateLabel(grant.date))
                    LabeledContent("授予总量", value: "\(ProfileRules.input(grant.shares)) 股")
                    LabeledContent("已归属", value: "\(ProfileRules.input(EquityRules.vested(grant, on: clock.now))) 股")
                    LabeledContent("未归属", value: "\(ProfileRules.input(grant.shares - EquityRules.vested(grant, on: clock.now) - grant.installments.filter(\.cancelled).reduce(0) { $0 + $1.shares })) 股")
                    LabeledContent("计划待补全", value: "\(ProfileRules.input(EquityRules.unallocated(grant))) 股")
                }
                Section {
                    ForEach(grant.installments.sorted { $0.date < $1.date }) { entry in
                        Button { editing = true } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                LabeledContent(CareerRules.dateLabel(entry.date), value: "\(ProfileRules.input(entry.shares)) 股")
                                Text(entry.cancelled ? "已取消" : entry.date <= ProfileRules.calendar.startOfDay(for: clock.now) ? "按计划已归属" : "待归属")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.foregroundStyle(.primary)
                        }
                    }
                    Button("编辑归属计划") { editing = true }
                } header: { Text("归属计划") } footer: { Text("已归属记录保留。实际延期可修改日期；取消的计划保留记录但不再计入持仓与未归属价值。") }
            }
        }.neutralPageBackground().navigationTitle(grant?.name ?? "授予详情")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("编辑") { editing = true } } }
        .sheet(isPresented: $editing) { EquityGrantEditor(holding: holding, companyName: companyName, existing: grant) }
    }
}

func equityField(_ title: String, text: Binding<String>) -> some View {
    LabeledContent(title) {
        TextField("请填写", text: text).multilineTextAlignment(.trailing).keyboardType(.decimalPad).accessibilityLabel(title)
    }
}
