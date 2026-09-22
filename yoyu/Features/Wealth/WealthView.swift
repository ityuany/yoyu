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
    @State private var cardHeights: [WealthCategory: CGFloat] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var profile: UserProfile? { profiles.max { $0.updatedAt(for: .wealth) < $1.updatedAt(for: .wealth) } }
    private var stockValue: Int64? { StockRules.portfolio(holdings, profile: profile, on: clock.now) }
    private var scenario: SeveranceScenario { SeveranceScenario(jobs: jobs, stages: stages, now: clock.now) }
    private var compensation: Int64? { scenario.estimate?.amountCents }
    private var total: Int64? { StockRules.wealth(holdings, profile: profile, on: clock.now) }
    private var needsReview: Bool { StockRules.needsLegacyReview(holdings, profile: profile) && !holdings.isEmpty }
    private var needsPrice: Bool { holdings.contains { !$0.priceIsConfigured } }
    private var summaryNotice: String? {
        if needsReview { return "股票记录待核对，资产与净值暂不可用。" }
        if needsPrice { return "部分股价待补全，资产与净值暂不可用。" }
        if profile?.cashCents == nil || profile?.investmentCents == nil {
            return "仅汇总已填写资产，未填写类别暂未计入。"
        }
        return nil
    }

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.wealthPath) {
            ScrollView {
                VStack(spacing: 0) {
                    WealthSummaryCard(
                        amount: total.map { ProfileRules.money($0) } ?? "待补全",
                        debt: liabilities.isEmpty ? "待记录" : LiabilityRules.total(liabilities, on: clock.now).map { compactBalance($0) } ?? "待核对",
                        netWorth: liabilities.isEmpty ? "待记录负债" : recordedNetWorth.map { compactBalance($0) } ?? "待补全",
                        notice: summaryNotice
                    )
                        .padding(.bottom, 20)

                    ZStack(alignment: .top) {
                        ForEach(WealthCategory.allCases) { category in
                            WealthCategoryCard(category: category, amount: categoryAmount(category),
                                               subtitle: category == .compensation ? "\(scenario.settings?.plan.title ?? "待配置") · 税前估算" : nil,
                                               isExpanded: expandedCategory == category) {
                                toggleCard(category)
                            } content: {
                                categoryContent(category)
                            }
                            .padding(.horizontal, DashboardStyle.pageInset)
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { height in
                                cardHeights[category] = height
                            }
                            .background(alignment: .top) {
                                // This opaque tail shares the card's z-order and translation,
                                // but never contributes to layout or intercepts a touch.
                                DashboardStyle.background
                                    .frame(height: occlusionHeight)
                                    // Begin behind the bottom corners so taller cards cannot leak there.
                                    .offset(y: cardHeight(category) - 28)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                            // Resolve the card as one geometry unit before moving it.
                            // Children must not animate their layout independently of the surface.
                            .transaction { $0.animation = nil }
                            .geometryGroup()
                            .frame(height: 0, alignment: .top)
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
                            .background(alignment: .top) {
                                DashboardStyle.background
                                    .frame(height: occlusionHeight)
                                    .offset(y: 28)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                            .transaction { $0.animation = nil }
                            .geometryGroup()
                            .padding(.top, CGFloat(WealthCategory.allCases.count) * WealthCardGeometry.headerHeight
                                     + expandedRevealDistance)
                            .zIndex(Double(WealthCategory.allCases.count))
                    }
                    .clipped()
                    .padding(.horizontal, -DashboardStyle.pageInset)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DashboardStyle.pageInset)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .background(DashboardStyle.background)
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

    private func compactBalance(_ cents: Int64) -> String {
        let yuan = Decimal(cents) / 100
        if cents >= 1_000_000 || cents <= -1_000_000 {
            return (yuan / 10_000).formatted(.number.precision(.fractionLength(2))) + "万"
        }
        return yuan.formatted(.number.precision(.fractionLength(2))) + "元"
    }

    private var recordedNetWorth: Int64? {
        guard let assets = StockRules.wealth(holdings, profile: profile, on: clock.now),
              let debts = LiabilityRules.total(liabilities, on: clock.now) else { return nil }
        return assets - debts
    }

    private func cardHeight(_ category: WealthCategory) -> CGFloat {
        cardHeights[category] ?? WealthCardGeometry.minimumHeight
    }

    private var expandedRevealDistance: CGFloat {
        guard let expandedCategory else { return 0 }
        return cardHeight(expandedCategory) - WealthCardGeometry.headerHeight + WealthCardGeometry.gap
    }

    private var occlusionHeight: CGFloat {
        // Bound both the largest surface and the largest animated translation.
        // Using every card keeps this coverage stable when selection changes.
        let tallest = WealthCategory.allCases.map { cardHeight($0) }.max() ?? WealthCardGeometry.minimumHeight
        return tallest * 2 + CGFloat(WealthCategory.allCases.count) * WealthCardGeometry.headerHeight
    }

    private func cardOffset(_ category: WealthCategory) -> CGFloat {
        let categories = WealthCategory.allCases
        guard let index = categories.firstIndex(of: category) else { return 0 }
        let expandedIndex = expandedCategory.flatMap { categories.firstIndex(of: $0) }
        let isBelowExpanded = expandedIndex.map { index > $0 } ?? false
        return CGFloat(index) * WealthCardGeometry.headerHeight
            + (isBelowExpanded ? expandedRevealDistance : 0)
    }

    private func categoryAmount(_ category: WealthCategory) -> String {
        switch category {
        case .cash: profile?.cashCents.map { ProfileRules.money($0) } ?? "待填写"
        case .stocks: stockValue.map { ProfileRules.money($0) } ?? (needsReview ? "待核对" : needsPrice ? "待补全股价" : "待记录")
        case .investment: profile?.investmentValue(on: clock.now).map { ProfileRules.money($0) } ?? "待填写"
        case .compensation: compensation.map { ProfileRules.money($0) } ?? "待完善"
        case .debt: liabilities.isEmpty ? "待记录" : LiabilityRules.total(liabilities, on: clock.now).map { ProfileRules.money($0) } ?? "待核对"
        }
    }

    @ViewBuilder private func categoryContent(_ category: WealthCategory) -> some View {
        switch category {
        case .cash:
            LabeledContent("现金余额", value: categoryAmount(.cash))
                .monospacedDigit()
            Text("记录随时可用的现金与存款余额。")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            NavigationLink { WealthAssetDetailView(asset: .cash) } label: {
                Text("查看资金详情")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
            }
        case .stocks:
            LabeledContent("已归属股数", value: stockShareCount(unvested: false))
                .monospacedDigit()
            LabeledContent("未归属股数", value: stockShareCount(unvested: true))
                .monospacedDigit()
            LabeledContent("已归属价值", value: ProfileRules.money(stockValue))
                .monospacedDigit()
            LabeledContent("未归属价值", value: ProfileRules.money(StockRules.portfolio(holdings, profile: profile, on: clock.now, unvested: true)))
                .monospacedDigit()
            Text(needsReview ? "旧股票记录待核对，暂不计算汇总。" : "总资产仅计入已归属部分，按手动设置的股价估算。")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            NavigationLink(value: WealthDestination.stocks) {
                Text("查看股票详情")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityHint("查看各公司股票和归属计划")
        case .investment:
            LabeledContent("年化收益率", value: profile?.investmentAnnualReturnBasisPoints.map { "\(ProfileRules.input($0))%" } ?? "待填写")
                .monospacedDigit()
            LabeledContent("预计年收益", value: ProfileRules.money(InvestmentProjection.calculate(
                principal: profile?.investmentCents,
                rate: profile?.investmentAnnualReturnBasisPoints,
                months: 12, mode: InvestmentInterestMode(rawValue: profile?.investmentInterestMode ?? "") ?? .simple)?.earningsCents))
                .monospacedDigit()
            Text("年收益按初始本金估算；卡片金额包含自登记日起的累计估算收益。")
                .font(.caption).foregroundStyle(.secondary)
            if profile?.investmentCents != nil && (profile?.investmentRegistrationDate == nil || profile?.investmentAnnualReturnBasisPoints == nil) {
                Text("待补登记日期或收益率，当前暂按本金显示。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            NavigationLink { WealthAssetDetailView(asset: .investment) } label: {
                Text("查看理财详情")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
            }
        case .compensation:
            ForEach(SeverancePlan.selectable) { plan in
                LabeledContent("补偿方案 \(plan.title)") {
                    Text(compensationAmount(for: plan))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
            Text("根据当前任职及工资基数估算，均为税前金额，尚未实际到账。")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            NavigationLink { SeveranceDetailView() } label: {
                Text(scenario.job == nil ? "完善当前任职" : "查看补偿方案")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
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
            }
        }
    }

    private func stockShareCount(unvested: Bool) -> String {
        let rows = StockRules.holdings(holdings)
        guard !StockRules.needsLegacyReview(rows, profile: profile) else { return "待核对" }
        guard !rows.isEmpty else { return "待记录" }
        var total = Decimal.zero
        for holding in rows {
            guard let balance = StockRules.balance(holding, on: clock.now) else { return "待补全" }
            total += Decimal(unvested ? balance.unvestedShares : balance.vestedShares)
        }
        return (total / 100).formatted(.number.precision(.fractionLength(0...2))) + " 股"
    }

    private func compensationAmount(for plan: SeverancePlan) -> String {
        let scenario = scenario
        guard let job = scenario.job, var settings = scenario.settings else { return "待完善" }
        settings.plan = plan
        return SeveranceRules.estimate(settings: settings, job: job, salaryCents: scenario.salaryCents, noticeSalaryCents: scenario.noticeSalaryCents, on: clock.now)
            .map { ProfileRules.money($0.amountCents) } ?? "待完善"
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
