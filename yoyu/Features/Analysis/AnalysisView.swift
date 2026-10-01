import SwiftUI
import SwiftData

struct AnalysisView: View {
    var isExample = false
    @Query private var profiles: [UserProfile]
    @Query private var stocks: [StockHolding]
    @Query private var jobs: [Employment]
    @Query private var stages: [SalaryStage]
    @Query private var bonuses: [BonusPayment]
    @Query private var expenses: [RecurringExpense]
    @Query private var liabilities: [LiabilityAccount]
    @Query private var contributions: [ContributionStage]
    @Query private var pensionLimits: [SocialInsuranceLimit]
    @Query private var housingLimits: [HousingFundLimit]
    @Query private var settings: [RunwaySettings]
    @Environment(CareerClock.self) private var clock
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @State private var mode: RunwayMode = .employed
    @State private var session = RunwaySession()
    private var shownResult: RunwayResult? { session.result(for: input.revision) }
    private var shownPlan: RunwayPlan { session.plan(for: input.revision) ?? plan }
    @State private var breakdown = false
    @State private var explaining = false
    @State private var compensation = false
    @State private var editingRetirement = false
    @State private var editing = false
    @State private var overviewFullscreen = false
    @State private var fullscreen = false
    @State private var investmentIncomeFullscreen = false
    @State private var example = false
    @State private var years = 5
    @State private var selection: Date?
    @State private var investmentIncomeSelection: Date?
    @State private var initialized = false
    @State private var saveError: String?
    @State private var editingAsset = false
    @State private var assetScope: WealthEditScope = .investment
    private var profile: UserProfile? { profiles.max { $0.updatedAt(for: .wealth) < $1.updatedAt(for: .wealth) } }
    private var plan: RunwayPlan { RunwayStore.record(settings, mode: mode)?.plan ?? RunwayPlan(mode: mode) }
    private var input: RunwayInput {
        RunwayInput(plan: plan, profile: profile, stocks: stocks, jobs: jobs,
                    stages: stages, bonuses: bonuses, expenses: expenses,
                    liabilities: liabilities, today: clock.now)
    }
    var body: some View {
        let currentInput = input
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isExample {
                        Label("示例数据 · 不影响你的账本", systemImage: "sparkles")
                            .font(.caption).foregroundStyle(AppTheme.secondaryText).accessibilityIdentifier("runway.example")
                    }
                    cardHeader.padding(.bottom, 8)
                    if !isExample {
                        contributionCards
                    }
                }.padding(20)
            }
            .background(Color("AnalysisOverviewPage").ignoresSafeArea())
            .dashboardTabRoot(title: "分析")
            .navigationDestination(for: CareerDestination.self) { CareerView(destination: $0) }
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .socialInsuranceLimits: SocialInsuranceLimitsView()
                case .housingFundLimits: HousingFundLimitsView()
                case .pensionShortfall: PensionShortfallView()
                case .housingShortfall: HousingShortfallView()
                case .holidays: HolidayScheduleView()
                case .sync: SyncStatusView()
                case .detail(let section): ProfileDetailView(section: section)
                }
            }
            .toolbar {
                if isExample { ToolbarItem(placement: .primaryAction) { ExampleCloseButton() } }
            }
            .fullScreenCover(isPresented: $overviewFullscreen) {
                if let result = shownResult {
                    RunwayFullscreen(result: result, plan: shownPlan, years: $years, selection: $selection)
                }
            }
            .saveErrorAlert($saveError)
        }
        .onAppear {
            if !initialized { mode = RunwayStore.active(settings)?.mode ?? .employed; initialized = true }
        }
        .onChange(of: RunwayStore.active(settings)?.mode) { _, active in
            if let active { mode = active; selection = nil }
        }
        .task(id: initialized ? currentInput.revision : "initializing") {
            guard initialized else { return }
            await session.run(currentInput)
        }
    }
    private var cardHeader: some View {
        let result = shownResult
        let valid = result?.issue == nil && result != nil
        let before = result.map { ($0.failure ?? .distantFuture) < $0.origin } ?? false
        return AnalysisSummaryCard(
            mode: shownPlan.mode.title,
            amount: valid ? (before ? "请调整失业计划" : overviewDuration(result!)) : (result?.issue == nil ? "正在计算…" : "还差一点资料"),
            notice: valid ? (before ? "失业前资金不足，请调整情景" : result!.failure.map { "预计 \(ExpenseRules.dateLabel($0)) 资金不足" } ?? "可维持至退休前") : (result?.issue ?? "正在整理收入、资产与开支"),
            resultIdentifier: valid ? "runway.result" : "runway.pending"
        ) {
            if let result, result.issue == nil, result.opening != nil {
                Divider().overlay(AnalysisOverviewStyle.accent.opacity(0.12))
                overviewTrend(result)
            }
        } destination: {
            detailPage
        }
    }

    private func overviewDuration(_ result: RunwayResult) -> String {
        guard result.failure == nil else { return result.duration }
        let months = ProfileRules.calendar.dateComponents([.month], from: result.origin, to: result.end).month ?? 0
        return "至少 \(months) 个月"
    }

    private func contributionTotal(_ kind: ContributionKind) -> Int64? {
        let values = CareerRules.employments(jobs).compactMap {
            ContributionEstimateRules.calculate(contributions, for: $0, kind: kind, through: clock.now)?.amountCents
        }
        return values.isEmpty ? nil : values.reduce(Int64.zero, +)
    }

    private var contributionCards: some View {
        let pension = PensionShortfallRules.calculate(jobs: jobs, salaries: stages, bonuses: bonuses, contributions: contributions, limits: pensionLimits, through: clock.now)
        let housing = HousingShortfallRules.calculate(jobs: jobs, salaries: stages, contributions: contributions, limits: housingLimits, through: clock.now)
        let pensionCompared = pension.reduce(0) { $0 + $1.comparableCount }
        let housingCompared = housing.reduce(0) { $0 + $1.comparableCount }
        return Group {
            AnalysisContributionCard(title: "养老保险", symbol: "shield.lefthalf.filled",
                total: contributionTotal(.pension),
                expected: pension.flatMap(\.months).filter { $0.personalShortfallCents != nil }.compactMap(\.expectedPaymentCents).reduce(Int64.zero, +),
                shortfall: pensionCompared == 0 ? nil : pension.reduce(Int64.zero) { $0 + $1.personalShortfallCents },
                compared: pensionCompared, missing: pension.reduce(0) { $0 + $1.missingCount },
                identifier: "analysis.pension", destination: .pension)
            AnalysisContributionCard(title: "住房公积金", symbol: "house.fill",
                total: contributionTotal(.housing),
                expected: housing.flatMap(\.months).filter { $0.personalShortfallCents != nil }.compactMap(\.expectedPaymentCents).reduce(Int64.zero, +),
                shortfall: housingCompared == 0 ? nil : housing.reduce(Int64.zero) { $0 + $1.personalShortfallCents },
                compared: housingCompared, missing: housing.reduce(0) { $0 + $1.missingCount },
                identifier: "analysis.housing", destination: .housing)
            Text("少缴为估算，非补缴认定")
                .font(.caption).foregroundStyle(AppTheme.secondaryText)
                .padding(.horizontal, 4)
        }
    }

    private func overviewTrend(_ result: RunwayResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            OverviewCardHeader {
                Text("资金趋势")
            } trailing: {
                Button { overviewFullscreen = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44)
                }
                .foregroundStyle(AppTheme.secondaryText)
                .accessibilityLabel("全屏查看资金趋势")
                .accessibilityIdentifier("analysis.expand")
            }
            .padding(.vertical, -8)
            VStack(alignment: .leading, spacing: 16) {
                Picker("图表时间范围", selection: $years) {
                    Text("1 年").tag(1)
                    Text("5 年").tag(5)
                    Text("完整").tag(0)
                }.pickerStyle(.segmented).accessibilityIdentifier("analysis.chartRange")
                RunwayChart(result: result, plan: shownPlan, years: years, selection: $selection)
                    .frame(height: 170)
                if let selected = selection,
                   let point = result.points.min(by: { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) }) {
                    overviewAssetRow(ExpenseRules.dateLabel(point.date), cents: point.total)
                } else if let opening = result.opening {
                    overviewAssetRow("起始资产", cents: opening.total)
                }
            }
        }
    }

    private func overviewAssetRow(_ title: String, cents: Int64) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                Spacer(minLength: 12)
                Text(AnalysisOverviewStyle.money(cents)).font(.title3.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(AnalysisOverviewStyle.accent).fixedSize()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                Text(AnalysisOverviewStyle.money(cents)).font(.title3.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(AnalysisOverviewStyle.accent)
            }
        }.accessibilityElement(children: .combine)
            .accessibilityLabel("\(title)，\(ProfileRules.money(cents))")
    }
    private var detailPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                resultSummary
                if session.calculating(for: input.revision) { Label("正在计算预测…", systemImage: "arrow.trianglehead.2.clockwise.rotate.90").font(.caption).foregroundStyle(AppTheme.secondaryText) }
                if let r = shownResult {
                    if let issue = r.issue { missing(issue) }
                    else {
                        scenarioSummary
                        if r.opening != nil {
                            assets(r)
                            chartRange
                            trend(r)
                            investmentIncomeTrend(r)
                            Button { breakdown = true } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("收入与开支").font(.headline)
                                        Text("查看每月收支与理财赎回").font(.caption).foregroundStyle(AppTheme.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }.padding(20).background(AppTheme.insetBackground, in: RoundedRectangle(cornerRadius: 22))
                            }.buttonStyle(.plain).accessibilityIdentifier("runway.breakdown")
                        }
                    }
                }
                Button { explaining = true } label: {
                    Label("测算依据与说明", systemImage: "info.circle").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                }
                if !isExample { Button("查看示例效果") { example = true }.font(.subheadline).accessibilityIdentifier("runway.demo") }
            }.padding(24)
        }
        .neutralPageBackground()
        .navigationTitle("生存时长")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("调整情景") { editing = true }
                    .accessibilityIdentifier("runway.edit")
            }
        }
        .sheet(isPresented: $editingRetirement) { ProfileEditor(section: .basic, profile: profile) }
        .sheet(isPresented: $editing) { RunwayEditor(records: settings, draft: plan) }
        .sheet(isPresented: $editingAsset) { ProfileEditor(section: .wealth, profile: profile, wealthScope: assetScope) }
        .sheet(isPresented: $example) { RunwayDemoHost() }
        .sheet(isPresented: $breakdown) {
            NavigationStack {
                if let r = shownResult { RunwayBreakdown(result: r).toolbar { ToolbarItem(placement: .topBarTrailing) { ExampleCloseButton() } } }
            }
        }
        .sheet(isPresented: $explaining) {
            NavigationStack { explanation.toolbar { ToolbarItem(placement: .topBarTrailing) { ExampleCloseButton() } } }
        }
        .sheet(isPresented: $compensation) {
            NavigationStack { SeveranceDetailView().toolbar { ToolbarItem(placement: .topBarTrailing) { ExampleCloseButton() } } }
        }
        .fullScreenCover(isPresented: $fullscreen) {
            if let result = shownResult { RunwayFullscreen(result: result, plan: shownPlan, years: $years, selection: $selection) }
        }
        .fullScreenCover(isPresented: $investmentIncomeFullscreen) {
            if let result = shownResult { RunwayInvestmentIncomeFullscreen(result: result, years: $years, selection: $investmentIncomeSelection) }
        }
    }
    private var resultSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("预测结果").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
            if let r = shownResult, r.issue == nil {
                let before = (r.failure ?? .distantFuture) < r.origin
                Text(before ? "请调整失业计划" : r.duration)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.7).lineLimit(1)
                    .accessibilityIdentifier("runway.detailResult")
                Text(before ? "预计在失业日期前已无法支付开支。" : r.failure.map { "预计在 \(ExpenseRules.dateLabel($0)) 首次无法支付到期支出。" } ?? "预计可维持至退休前。")
                    .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                Text("从 \(ExpenseRules.dateLabel(r.origin)) 起算 · \(shownPlan.mode.title) · 税前口径")
                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
            } else {
                Text(shownResult?.issue == nil ? "正在计算预测…" : "还差一点资料")
                    .font(.title2.bold())
                Text(shownResult?.issue ?? "正在整理你的收入、资产与开支。")
                    .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var scenarioSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前情景").font(.headline)
            summaryRow("情景模式", shownPlan.mode.title)
            if mode == .employed {
                Text("继续在当前公司工作，沿用任职薪资与发薪日。")
            } else {
                if let loss = shownPlan.lossDate { summaryRow("失业时间", ExpenseRules.dateLabel(loss)) }
                if mode == .temporary, let back = shownPlan.returnDate {
                    summaryRow("重新就业", ExpenseRules.dateLabel(back))
                    summaryRow("就业薪资", ProfileRules.money(shownPlan.salary) + " /月")
                }
                summaryRow("灵活收入", ProfileRules.money(shownPlan.flexible) + " /月")
            }
        }.font(.subheadline).foregroundStyle(AppTheme.secondaryText)
    }
    private func summaryRow(_ title: String, _ value: String) -> some View { HStack { Text(title); Spacer(); Text(value).foregroundStyle(AppTheme.primaryText) } }
    private func missing(_ message: String) -> some View {
        let needsScenario = RunwayEngine.validation(plan, today: clock.now) != nil
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(needsScenario ? "完善这次情景" : "还差一点资料").font(.title3.bold())
                Text(message).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("runway.missing")
            }
            if message.contains("退休") || message.contains("出生年月") {
                Button { editingRetirement = true } label: { preparationAction("完善出生年月与退休信息") }
                    .accessibilityIdentifier("runway.editRetirement")
            } else if !needsScenario && (message.contains("理财") || message.contains("现金")) {
                Button {
                    assetScope = message.contains("理财") ? .investment : .cash
                    editingAsset = true
                } label: { preparationAction(message.contains("理财") ? "完善理财资料" : "登记现金余额") }
            } else if !needsScenario && message.contains("补偿") {
                Button { compensation = true } label: { preparationAction("完善裁员补偿") }
            } else if !needsScenario {
                Button {
                    navigation.selectedTab = message.contains("薪资") || message.contains("任职") ? .profile : .wealth
                } label: { preparationAction(message.contains("薪资") || message.contains("任职") ? "完善任职与薪资" : "前往财富完善资料") }
            }
        }.buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading).padding(22)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 22))
    }
    private func preparationAction(_ title: String) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
        }
        .foregroundStyle(AppTheme.primaryText).padding(.horizontal, 16).frame(minHeight: 48)
        .background(DashboardStyle.cash.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    private var chartRange: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("时间范围").font(.subheadline.weight(.semibold))
                Spacer()
                Text("应用于下方两张图表").font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
            Picker("图表时间范围", selection: $years) {
                Text("未来 1 年").tag(1)
                Text("未来 5 年").tag(5)
                Text("完整过程").tag(0)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("runway.chartRange")
        }
    }
    private func trend(_ r: RunwayResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("资金如何变化").font(.headline)
                Spacer()
                Button { fullscreen = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("全屏查看资产趋势").accessibilityIdentifier("runway.expand")
            }
            RunwayChart(result: r, plan: shownPlan, years: years, selection: $selection).frame(height: 220)
            if let selection, let p = r.points.min(by: { abs($0.date.timeIntervalSince(selection)) < abs($1.date.timeIntervalSince(selection)) }) {
                Text("\(ExpenseRules.dateLabel(p.date)) · 资产 \(ProfileRules.money(p.total))").font(.caption).monospacedDigit()
                Text("现金 \(ProfileRules.money(p.cash)) · 股票 \(ProfileRules.money(p.stock)) · 理财 \(ProfileRules.money(p.investment))").font(.caption2).foregroundStyle(AppTheme.secondaryText)
            } else {
                Text("点选日期查看资产构成 · 范围仅影响图表展示").font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
    private func investmentIncomeTrend(_ r: RunwayResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("理财收益如何变化").font(.headline)
                Spacer()
                Button { investmentIncomeFullscreen = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("全屏查看理财收益趋势").accessibilityIdentifier("runway.expandInvestmentIncome")
            }
            RunwayInvestmentIncomeChart(result: r, years: years, selection: $investmentIncomeSelection).frame(height: 220)
            if let investmentIncomeSelection, let point = RunwayInvestmentIncomeChart.monthlyPoints(result: r).min(by: { abs($0.date.timeIntervalSince(investmentIncomeSelection)) < abs($1.date.timeIntervalSince(investmentIncomeSelection)) }) {
                Text("\(ProfileRules.calendar.dateComponents([.year, .month], from: point.date).year!) 年 \(ProfileRules.calendar.dateComponents([.month], from: point.date).month!) 月 · 理财收益 \(ProfileRules.money(point.gain))")
                    .font(.caption).monospacedDigit()
            } else {
                Text("按月展示理财产生的收益，不含本金和赎回金额。")
                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
    private func assets(_ r: RunwayResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(mode == .employed ? "当前资产" : "失业起始资产").font(.headline)
                Spacer()
                Text("测算起点").font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
            if let p = r.opening {
                Text(ProfileRules.money(p.total))
                    .font(.title2.bold()).monospacedDigit()
                    .accessibilityIdentifier("runway.openingTotal")
                VStack(alignment: .leading, spacing: 10) {
                    summaryRow("现金", ProfileRules.money(p.cash - r.compensation))
                    summaryRow("已归属股票", ProfileRules.money(p.stock))
                    summaryRow("理财", ProfileRules.money(p.investment))
                    if mode != .employed { summaryRow("裁员补偿", ProfileRules.money(r.compensation)) }
                }
                .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            }
            Text("支付开支时，依次使用现金、股票、理财；理财只赎回所需金额。")
                .font(.caption).foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var explanation: some View {
        List {
            Section("资金与日期") {
                Text("从最新登记的财富出发，按天推算。失业前的工资、收益及支出影响失业起始本金；补偿仅在失业当天加入。")
                Text("现金视为今天开始前的余额，今天的到账收入与开支会计入一次；请避免将已经包含当天流水的余额重复用于测算。")
            }.listRowBackground(AppTheme.cardBackground)
            Section("收入口径") {
                Text("统一按税前计算。每个发薪日按当天情景计入对应月薪，暂不处理工资所属月份、离职结薪或不足整月工资的追溯。灵活收入同样按到账日所在情景计入。")
                Text("理财收益留在理财中，沿用财富的单利或每满 365 天复投规则。赎回先使用未复投收益，再使用本金，已取出的资金不再计息。")
            }.listRowBackground(AppTheme.cardBackground)
            Section("生存结果") {
                Text("全部可用资金不足以支付到期支出的首日为终点。系统推算至退休年月；在此之前未找到终点时，显示截至退休前至少可生存的时长。")
            }.listRowBackground(AppTheme.cardBackground)
            Section("数据来源") {
                Text("生活支出直接读取日常开支记录；还款只读取负债的还款安排，不再叠加财富页面汇总值。未计入通胀、股价变化、未来未登记的股票归属及未登记消费。")
            }.listRowBackground(AppTheme.cardBackground)
        }.navigationTitle("测算依据").navigationBarTitleDisplayMode(.inline)
    }
}

private struct ExampleCloseButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { Button("关闭") { dismiss() } }
}

private struct RunwayBreakdown: View {
    let result: RunwayResult
    var body: some View {
        List {
            ForEach(result.points.filter { $0.date > result.origin }) { p in
                Section(ExpenseRules.dateLabel(p.date)) {
                    LabeledContent("工资与灵活收入", value: ProfileRules.money(p.income))
                    LabeledContent("理财收益", value: ProfileRules.money(p.gain))
                    LabeledContent("生活支出", value: ProfileRules.money(p.expense))
                    LabeledContent("还款", value: ProfileRules.money(p.repayment))
                    LabeledContent("按需赎回", value: ProfileRules.money(p.redeemed))
                    LabeledContent("剩余资产", value: ProfileRules.money(p.total))
                }.listRowBackground(AppTheme.cardBackground)
            }
        }.navigationTitle("收支明细").navigationBarTitleDisplayMode(.inline)
    }
}
