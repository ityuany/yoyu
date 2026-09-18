import SwiftUI
import SwiftData

struct WealthView: View {
    @Query private var profiles: [UserProfile]
    @Query private var holdings: [StockHolding]
    @Query private var jobs: [Employment]
    @Query private var stages: [SalaryStage]
    @Query private var liabilities: [LiabilityAccount]
    @Environment(AppNavigation.self) private var navigation
    @Environment(CareerClock.self) private var clock

    private var profile: UserProfile? { profiles.max { $0.updatedAt(for: .wealth) < $1.updatedAt(for: .wealth) } }
    private var stockValue: Int64? { StockRules.portfolio(holdings, profile: profile, on: clock.now) }
    private var scenario: SeveranceScenario { SeveranceScenario(jobs: jobs, stages: stages, now: clock.now) }
    private var compensation: Int64? { scenario.estimate?.amountCents }
    private var total: Int64? { StockRules.wealth(holdings, profile: profile, on: clock.now, compensationCents: compensation) }
    private var needsReview: Bool { StockRules.needsLegacyReview(holdings, profile: profile) && !holdings.isEmpty }
    private var needsPrice: Bool { holdings.contains { !$0.priceIsConfigured } }
    private var composition: [(name: String, amount: Double, color: Color)] {
        [("现金", profile?.cashCents, DashboardStyle.cash), ("股票", stockValue, DashboardStyle.stock), ("理财", profile?.investmentCents, DashboardStyle.investment), ("补偿", compensation, DashboardStyle.compensation)]
            .compactMap { name, cents, color in
                guard let cents else { return nil }
                return (name, Double(cents), color)
            }
    }

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.wealthPath) {
            List {
                Section {
                    WealthSummaryCard(amount: total.map { ProfileRules.money($0) } ?? (needsReview ? "待核对股票" : needsPrice ? "待补全股价" : "待填写"), composition: composition, needsPrice: needsPrice)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if !liabilities.isEmpty {
                    Section {
                        LabeledContent("当前负债", value: LiabilityRules.total(liabilities, on: clock.now).map { ProfileRules.money($0) } ?? "待核对")
                        LabeledContent("资产净值", value: recordedNetWorth.map { ProfileRules.money($0) } ?? "待补全资产")
                    } footer: {
                        Text("净值按现金、已归属股票和理财减当前负债计算。自动分期按日期估算；不含房产估值、未归属股票与预计补偿。")
                    }
                }
                Section("资产明细") {
                    NavigationLink { WealthAssetDetailView(asset: .cash) } label: {
                        assetRow("现金", icon: "banknote", color: DashboardStyle.cash, value: profile?.cashCents, empty: "添加现金余额")
                    }
                    NavigationLink(value: WealthDestination.stocks) {
                        assetRow("股票", icon: "chart.bar.fill", color: DashboardStyle.stock, value: stockValue,
                                 empty: needsReview ? "待核对旧记录" : needsPrice ? "待设置股价" : holdings.isEmpty && StockRules.legacy(profile) == nil ? "记录股票激励" : "待补全")
                    }
                    NavigationLink { WealthAssetDetailView(asset: .investment) } label: {
                        assetRow("理财", icon: "chart.pie.fill", color: DashboardStyle.investment, value: profile?.investmentCents, empty: "添加理财资产")
                    }
                }
                Section("未来资产") {
                    NavigationLink { SeveranceDetailView() } label: {
                        assetRow("补偿", icon: "briefcase.fill", color: DashboardStyle.compensation, value: compensation, empty: scenario.job == nil ? "完善当前任职" : "完善补偿方案")
                    }
                }
                Section("负债明细") {
                    ForEach(LiabilityKind.allCases) { kind in
                        NavigationLink { LiabilityOverviewView(filter: kind) } label: {
                            let accounts = LiabilityRules.accounts(liabilities).filter { $0.kind == kind }
                            assetRow(kind.title, icon: kind.icon, color: DashboardStyle.accent,
                                     value: accounts.isEmpty ? nil : LiabilityRules.total(accounts, on: clock.now), empty: accounts.isEmpty ? "添加" + kind.title : "待核对")
                        }
                    }
                    NavigationLink { DebtScheduleView(accounts: LiabilityRules.accounts(liabilities)) } label: {
                        Label("每月已知还款", systemImage: "calendar")
                    }
                    if liabilities.isEmpty {
                        NavigationLink { LiabilityExampleView() } label: {
                            Label("查看组合贷与分期示例", systemImage: "sparkles")
                        }
                    }
                }
            }.neutralPageBackground()
            .listStyle(.insetGrouped)
            .dashboardTabRoot(title: "财富")
            .navigationDestination(for: WealthDestination.self) { destination in
                switch destination {
                case .debtExample: LiabilityExampleView()
                case .stocks: StockPortfolioView()
                case .holding(let id):
                    if let holding = StockRules.holdings(holdings).first(where: { $0.id == id }) {
                        EquityOverview(holding: holding, companyName: jobs.first { $0.id == holding.employmentID }?.displayName ?? holding.name)
                    } else {
                        ContentUnavailableView("股票记录已不可用", systemImage: "chart.bar", description: Text("请返回股票列表查看。"))
                    }
                }
            }
        }
    }

    private var recordedNetWorth: Int64? {
        guard let assets = StockRules.wealth(holdings, profile: profile, on: clock.now),
              let debts = LiabilityRules.total(liabilities, on: clock.now) else { return nil }
        return assets - debts
    }

    private func assetRow(_ title: String, icon: String, color: Color, value: Int64?, empty: String) -> some View {
        LabeledContent {
            Text(value.map { ProfileRules.money($0) } ?? empty)
                .monospacedDigit()
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
        }
    }
}
