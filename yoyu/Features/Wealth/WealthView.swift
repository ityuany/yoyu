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

    @State private var expandedCategory: WealthCategory?
    @State private var editingAsset: WealthEditScope?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var profile: UserProfile? { profiles.max { $0.updatedAt(for: .wealth) < $1.updatedAt(for: .wealth) } }
    private var stockValue: Int64? { StockRules.portfolio(holdings, profile: profile, on: clock.now) }
    private var scenario: SeveranceScenario { SeveranceScenario(jobs: jobs, stages: stages, now: clock.now) }
    private var compensation: Int64? { scenario.estimate?.amountCents }
    private var total: Int64? { StockRules.wealth(holdings, profile: profile, on: clock.now, compensationCents: compensation) }
    private var needsReview: Bool { StockRules.needsLegacyReview(holdings, profile: profile) && !holdings.isEmpty }
    private var needsPrice: Bool { holdings.contains { !$0.priceIsConfigured } }
    private var composition: [(name: String, amount: Double, color: Color)] {
        [("现金", profile?.cashCents, WealthCategory.cash.marker), ("股票", stockValue, WealthCategory.stocks.marker), ("理财", profile?.investmentCents, WealthCategory.investment.marker), ("补偿", compensation, WealthCategory.compensation.marker)]
            .compactMap { name, cents, color in
                guard let cents else { return nil }
                return (name, Double(cents), color)
            }
    }

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.wealthPath) {
            ScrollView {
                VStack(spacing: 0) {
                    WealthSummaryCard(amount: total.map { ProfileRules.money($0) } ?? (needsReview ? "待核对股票" : needsPrice ? "待补全股价" : "待填写"), composition: composition, needsPrice: needsPrice)
                        .padding(.bottom, 28)

                    ZStack(alignment: .top) {
                        ForEach(WealthCategory.allCases) { category in
                            WealthCategoryCard(category: category, amount: categoryAmount(category),
                                               isExpanded: expandedCategory == category) {
                                toggleCard(category)
                            } content: {
                                categoryContent(category)
                            }
                            // Resolve the card as one geometry unit before moving it.
                            // Children must not animate their layout independently of the surface.
                            .transaction { $0.animation = nil }
                            .geometryGroup()
                            .offset(y: cardOffset(category))
                            .zIndex(Double(WealthCategory.allCases.firstIndex(of: category)!))
                        }

                        // This final, always-open card determines the stack's natural height.
                        // Its opaque surface covers the debt body just like the other cards.
                        ExpenseHomeSection(cardLayout: true, onSelectCard: { setExpandedCategory(nil) })
                            .padding(.vertical, 22)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 28))
                            .overlay {
                                RoundedRectangle(cornerRadius: 28)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                    .allowsHitTesting(false)
                            }
                            .transaction { $0.animation = nil }
                            .geometryGroup()
                            .padding(.top, CGFloat(WealthCategory.allCases.count) * WealthCardGeometry.headerHeight
                                     + (expandedCategory == nil ? 0 : WealthCardGeometry.revealDistance))
                            .zIndex(Double(WealthCategory.allCases.count))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DashboardStyle.pageInset)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .background(DashboardStyle.background)
            .sheet(item: $editingAsset) { asset in
                ProfileEditor(section: .wealth, profile: profile, wealthScope: asset)
            }
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

    private func toggleCard(_ category: WealthCategory) {
        setExpandedCategory(expandedCategory == category ? nil : category)
    }

    private func setExpandedCategory(_ next: WealthCategory?) {
        guard expandedCategory != next else { return }
        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { expandedCategory = next }
        } else {
            // Move directly to the selected arrangement, without an intermediate closed state.
            withAnimation(.timingCurve(0.18, 0.65, 0.25, 1, duration: 0.32)) {
                expandedCategory = next
            }
        }
    }

    private var recordedNetWorth: Int64? {
        guard let assets = StockRules.wealth(holdings, profile: profile, on: clock.now),
              let debts = LiabilityRules.total(liabilities, on: clock.now) else { return nil }
        return assets - debts
    }

    private func cardOffset(_ category: WealthCategory) -> CGFloat {
        let categories = WealthCategory.allCases
        guard let index = categories.firstIndex(of: category) else { return 0 }
        let expandedIndex = expandedCategory.flatMap { categories.firstIndex(of: $0) }
        let isBelowExpanded = expandedIndex.map { index > $0 } ?? false
        return CGFloat(index) * WealthCardGeometry.headerHeight
            + (isBelowExpanded ? WealthCardGeometry.revealDistance : 0)
    }

    private func categoryAmount(_ category: WealthCategory) -> String {
        switch category {
        case .cash: profile?.cashCents.map { ProfileRules.money($0) } ?? "待填写"
        case .stocks: stockValue.map { ProfileRules.money($0) } ?? (needsReview ? "待核对" : needsPrice ? "待补全股价" : "待记录")
        case .investment: profile?.investmentCents.map { ProfileRules.money($0) } ?? "待填写"
        case .compensation: compensation.map { ProfileRules.money($0) } ?? "待完善"
        case .debt: liabilities.isEmpty ? "待记录" : LiabilityRules.total(liabilities, on: clock.now).map { ProfileRules.money($0) } ?? "待核对"
        }
    }

    @ViewBuilder private func categoryContent(_ category: WealthCategory) -> some View {
        switch category {
        case .cash:
            Text("记录随时可用的现金与存款余额。")
                .foregroundStyle(.secondary)
            NavigationLink { WealthAssetDetailView(asset: .cash) } label: {
                detailLink("现金余额", icon: "banknote", value: categoryAmount(.cash))
            }
            Button { editingAsset = .cash } label: {
                Label(profile?.cashCents == nil ? "添加现金余额" : "更新现金余额", systemImage: "plus.circle")
            }
        case .stocks:
            LabeledContent("未归属价值", value: ProfileRules.money(StockRules.portfolio(holdings, profile: profile, on: clock.now, unvested: true)))
                .monospacedDigit()
            Text(needsReview ? "旧股票记录待核对，暂不计算汇总。" : "总资产仅计入已归属部分，按手动设置的股价估算。")
                .font(.caption).foregroundStyle(.secondary)
            NavigationLink(value: WealthDestination.stocks) {
                detailLink(holdings.isEmpty ? "记录股票激励" : "查看公司与归属计划", icon: "chart.bar")
            }
        case .investment:
            LabeledContent("年化收益率", value: profile?.investmentAnnualReturnBasisPoints.map { "\(ProfileRules.input($0))%" } ?? "待填写")
                .monospacedDigit()
            NavigationLink { WealthAssetDetailView(asset: .investment) } label: {
                detailLink("理财详情与收益测算", icon: "chart.line.uptrend.xyaxis")
            }
            Button { editingAsset = .investment } label: {
                Label(profile?.investmentCents == nil ? "添加理财资产" : "更新理财资产", systemImage: "plus.circle")
            }
        case .compensation:
            Text("根据当前任职和补偿方案估算，尚未实际到账。")
                .foregroundStyle(.secondary)
            NavigationLink { SeveranceDetailView() } label: {
                detailLink(scenario.job == nil ? "完善当前任职" : "查看补偿方案", icon: "briefcase")
            }
        case .debt:
            ForEach(LiabilityKind.allCases) { kind in
                NavigationLink { LiabilityOverviewView(filter: kind) } label: {
                    let accounts = LiabilityRules.accounts(liabilities).filter { $0.kind == kind }
                    detailLink(kind.title, icon: kind.icon,
                               value: accounts.isEmpty ? "添加" : LiabilityRules.total(accounts, on: clock.now).map { ProfileRules.money($0) } ?? "待核对")
                }
            }
            if liabilities.isEmpty {
                NavigationLink { LiabilityExampleView() } label: {
                    detailLink("查看组合贷与分期示例", icon: "sparkles")
                }
            } else {
                LabeledContent("资产净值", value: recordedNetWorth.map { ProfileRules.money($0) } ?? "待补全资产")
                    .monospacedDigit()
                Text("净值不含房产、未归属股票与预计补偿。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func detailLink(_ title: String, icon: String, value: String? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).frame(width: 22)
            Text(title)
            Spacer(minLength: 4)
            if let value { Text(value).monospacedDigit() }
            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).opacity(0.6)
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }
}
