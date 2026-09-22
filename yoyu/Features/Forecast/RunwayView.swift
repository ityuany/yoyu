import SwiftUI
import SwiftData

struct RunwayView: View {
    var isExample = false
    @Query private var profiles: [UserProfile]
    @Query private var stocks: [StockHolding]
    @Query private var jobs: [Employment]
    @Query private var stages: [SalaryStage]
    @Query private var expenses: [RecurringExpense]
    @Query private var liabilities: [LiabilityAccount]
    @Query private var settings: [RunwaySettings]
    @Environment(CareerClock.self) private var clock
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.modelContext) private var context
    @State private var mode: RunwayMode = .employed
    @State private var result: RunwayResult?
    @State private var resultPlan: RunwayPlan?
    @State private var updating = false
    @State private var requestID = UUID()
    private var shownResult: RunwayResult? { resultPlan?.mode == mode ? result : nil }
    private var shownPlan: RunwayPlan { resultPlan ?? plan }
    @State private var cardFrame = CGRect.zero
    @State private var expansionOrigin = CGRect.zero
    @State private var breakdown = false
    @State private var explaining = false
    @State private var compensation = false
    @State private var detail = false
    @State private var editing = false
    @State private var fullscreen = false
    @State private var example = false
    @State private var years = 5
    @State private var selection: Date?
    @State private var initialized = false
    @State private var saveError: String?
    @State private var editingAsset = false
    @State private var assetScope: WealthEditScope = .investment
    private var profile: UserProfile? { profiles.max { $0.updatedAt(for: .wealth) < $1.updatedAt(for: .wealth) } }
    private var plan: RunwayPlan { RunwayStore.record(settings, mode: mode)?.plan ?? RunwayPlan(mode: mode) }
    private var wealthKey: String {
        guard let p = profile else { return "no-profile" }
        let values: [String?] = [p.wealthUpdatedAt?.timeIntervalSinceReferenceDate.description,
            p.cashCents?.description, p.stockCents?.description, p.stockSharesHundredths?.description,
            p.stockPriceCents?.description, p.investmentCents?.description,
            p.investmentAnnualReturnBasisPoints?.description, p.investmentInterestMode,
            p.investmentRegistrationDate?.timeIntervalSinceReferenceDate.description]
        return values.map { $0 ?? "nil" }.joined(separator: "/")
    }
    private var key: String {
        [ProfileRules.dateKey(clock.now), mode.rawValue,
         plan.cacheKey,
         wealthKey,
         jobs.map { "\($0.id)\($0.modifiedAt.timeIntervalSinceReferenceDate)" }.sorted().joined(), stages.map { "\($0.id)\($0.modifiedAt.timeIntervalSinceReferenceDate)" }.sorted().joined(),
         stocks.map { "\($0.id)\($0.modifiedAt.timeIntervalSinceReferenceDate)" }.sorted().joined(), expenses.map { "\($0.id)\($0.modifiedAt.timeIntervalSinceReferenceDate)" }.sorted().joined(), liabilities.map { "\($0.id)\($0.modifiedAt.timeIntervalSinceReferenceDate)" }.sorted().joined()].joined(separator: "|")
    }
    var body: some View {
        ZStack {
            home
                .allowsHitTesting(!detail)
                .accessibilityHidden(detail)
            if detail { detailPage.transition(.identity).zIndex(1) }
        }
        .toolbar(detail ? .hidden : .visible, for: .tabBar)
        .interactiveDismissDisabled(detail)
    }
    private var home: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isExample {
                        Label("示例数据 · 不影响你的账本", systemImage: "sparkles")
                            .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("runway.example")
                    }
                    Button { presentDetail(true) } label: {
                        cardHeader(expanded: false)
                            .background(cardBackground, in: RoundedRectangle(cornerRadius: 28))
                    }
                    .buttonStyle(RunwayCardPressStyle())
                    .accessibilityIdentifier("runway.card")
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { cardFrame = $0 }
                }.padding(20)
            }
            .accessibilityHidden(detail)
            .neutralPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isExample { ToolbarItem(placement: .primaryAction) { ExampleCloseButton() } }
            }
            .onAppear {
                if !initialized { mode = RunwayStore.active(settings)?.mode ?? .employed; initialized = true }
            }
            .onChange(of: RunwayStore.active(settings)?.mode) { _, active in
                if let active { mode = active; selection = nil }
            }
            .task(id: initialized ? key : "initializing") {
                guard initialized else { return }
                let request = UUID(), currentKey = key, currentPlan = plan
                requestID = request
                if let cached = navigation.runwayCache.result(for: currentKey) {
                    result = cached; resultPlan = currentPlan; updating = false
                    return
                }
                updating = true
                defer { if requestID == request { updating = false } }
                let next = await RunwayEngine.calculate(plan: currentPlan, profile: profile, stocks: stocks, jobs: jobs, stages: stages, expenses: expenses, liabilities: liabilities, today: clock.now)
                guard !Task.isCancelled, requestID == request, key == currentKey else { return }
                navigation.runwayCache.store(next, for: currentKey)
                result = next; resultPlan = currentPlan
            }
            .saveErrorAlert($saveError)
        }
    }
    private var cardBackground: LinearGradient {
        LinearGradient(colors: [DashboardStyle.cash.opacity(0.18), DashboardStyle.cash.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private var cardHeading: some View {
        HStack {
            Text("生存时长").font(.headline)
            Spacer()
        }
    }
    private func presentDetail(_ value: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if value { expansionOrigin = cardFrame }
            detail = value
        }
    }
    @ViewBuilder private func cardHeader(expanded: Bool) -> some View {
        if let r = shownResult, r.issue == nil { hero(r, expanded: expanded) }
        else {
            VStack(alignment: .leading, spacing: 18) {
                cardHeading
                Text(shownResult?.issue == nil ? "正在计算预测…" : "还差一点资料").font(.title2.bold())
                Text(shownResult?.issue ?? "正在整理你的收入、资产与开支。")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("当前情景 · \(mode.title)").font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var detailPage: some View {
        RunwayCardExpansion(source: expansionOrigin, onClose: { presentDetail(false) }) {
            cardHeader(expanded: true)
        } details: {
            VStack(alignment: .leading, spacing: 28) {
                if updating { Label("正在按新设置更新…", systemImage: "arrow.trianglehead.2.clockwise.rotate.90").font(.caption).foregroundStyle(.secondary) }
                if let r = shownResult {
                    if let issue = r.issue { missing(issue) }
                    else {
                        scenarioSummary
                        if r.opening != nil {
                            trend(r)
                            assets(r)
                            Button { breakdown = true } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("收入与开支").font(.headline)
                                        Text("查看每月收支与理财赎回").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }.padding(20).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 22))
                            }.buttonStyle(.plain).accessibilityIdentifier("runway.breakdown")
                        }
                    }
                }
                Button { explaining = true } label: {
                    Label("测算依据与说明", systemImage: "info.circle").font(.subheadline).foregroundStyle(.secondary)
                }
                if !isExample { Button("查看示例效果") { example = true }.font(.subheadline).accessibilityIdentifier("runway.demo") }
            }.padding(24)
        }
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
    }
    private func hero(_ r: RunwayResult, expanded: Bool = false) -> some View {
        let before = (r.failure ?? .distantFuture) < r.origin
        return VStack(alignment: .leading, spacing: 16) {
            cardHeading
            Text("当前情景 · \(shownPlan.mode.title)").font(.subheadline.weight(.medium))
            Label(before ? "失业前资金不足" : r.sustainable ? "按当前配置" : r.failure == nil ? "按当前情景，至少可生存" : "按当前情景，预计可生存", systemImage: before ? "exclamationmark.circle" : "leaf")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(before ? "请调整失业计划" : r.sustainable ? "可持续生存" : r.duration)
                .font(.system(size: 35, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.7).lineLimit(1)
                .accessibilityIdentifier(expanded ? "runway.detailResult" : "runway.result")
            Text(before ? "预计在 \(ExpenseRules.dateLabel(r.failure!)) 已无法支付开支，尚未到达失业日期。" : r.sustainable ? "工资、灵活收入或理财收益足以覆盖长期支出，且已有充足现金缓冲。" : r.failure.map { "预计在 \(ExpenseRules.dateLabel($0)) 首次无法支付到期支出" } ?? "在本次计算范围内，全部资金仍能支撑生活。")
                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider().overlay(DashboardStyle.cash.opacity(0.1))
            HStack {
                Text("\(ExpenseRules.dateLabel(r.origin)) 起算")
                Spacer()
                Text("税前口径")
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
    }
    private var scenarioSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("当前情景").font(.headline)
                Spacer()
                Button("调整情景") { editing = true }.font(.subheadline).accessibilityIdentifier("runway.edit")
            }
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
        }.font(.subheadline).foregroundStyle(.secondary)
    }
    private func summaryRow(_ title: String, _ value: String) -> some View { HStack { Text(title); Spacer(); Text(value).foregroundStyle(.primary) } }
    private func missing(_ message: String) -> some View {
        let needsScenario = RunwayEngine.validation(plan, today: clock.now) != nil
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(needsScenario ? "完善这次情景" : "还差一点资料").font(.title3.bold())
                Text(message).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("runway.missing")
            }
            if needsScenario || isExample {
                Button { editing = true } label: { preparationAction("调整情景") }
                    .accessibilityIdentifier("runway.edit")
            } else if message.contains("理财") || message.contains("现金") {
                Button {
                    assetScope = message.contains("理财") ? .investment : .cash
                    editingAsset = true
                } label: { preparationAction(message.contains("理财") ? "完善理财资料" : "登记现金余额") }
            } else if message.contains("补偿") {
                Button { compensation = true } label: { preparationAction("完善裁员补偿") }
            } else {
                Button {
                    presentDetail(false)
                    navigation.selectedTab = message.contains("薪资") || message.contains("任职") ? .profile : .wealth
                } label: { preparationAction(message.contains("薪资") || message.contains("任职") ? "完善任职与薪资" : "前往财富完善资料") }
            }
            if !needsScenario && !isExample {
                Button("调整情景") { editing = true }.font(.subheadline).accessibilityIdentifier("runway.edit")
            }
        }.buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading).padding(22)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
    private func preparationAction(_ title: String) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
        }
        .foregroundStyle(.primary).padding(.horizontal, 16).frame(minHeight: 48)
        .background(DashboardStyle.cash.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    private func trend(_ r: RunwayResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("资金如何变化").font(.headline)
                Spacer()
                Button { fullscreen = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("全屏查看资产趋势").accessibilityIdentifier("runway.expand")
            }
            Picker("查看范围", selection: $years) { Text("未来 1 年").tag(1); Text("未来 5 年").tag(5); Text("完整过程").tag(0) }.pickerStyle(.segmented)
            RunwayChart(result: r, plan: shownPlan, years: years, selection: $selection).frame(height: 220)
            if let selection, let p = r.points.min(by: { abs($0.date.timeIntervalSince(selection)) < abs($1.date.timeIntervalSince(selection)) }) {
                Text("\(ExpenseRules.dateLabel(p.date)) · 资产 \(ProfileRules.money(p.total))").font(.caption).monospacedDigit()
                Text("现金 \(ProfileRules.money(p.cash)) · 股票 \(ProfileRules.money(p.stock)) · 理财 \(ProfileRules.money(p.investment))").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("点选日期查看资产构成 · 范围仅影响图表展示").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func assets(_ r: RunwayResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mode == .employed ? "当前资产" : "失业起始本金").font(.headline)
            if let p = r.opening {
                Text(ProfileRules.money(p.total)).font(.title.bold()).monospacedDigit()
                summaryRow("现金", ProfileRules.money(p.cash - r.compensation))
                summaryRow("已归属股票", ProfileRules.money(p.stock))
                summaryRow("理财", ProfileRules.money(p.investment))
                if mode != .employed { summaryRow("裁员补偿", ProfileRules.money(r.compensation)) }
            }
            Text("支付开支时，依次使用现金、股票、理财。理财只赎回所需金额。").font(.caption).foregroundStyle(.secondary)
        }.padding(20).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 22))
    }
    private var explanation: some View {
        List {
            Section("资金与日期") {
                Text("从最新登记的财富出发，按天推算。失业前的工资、收益及支出影响失业起始本金；补偿仅在失业当天加入。")
                Text("现金视为今天开始前的余额，今天的到账收入与开支会计入一次；请避免将已经包含当天流水的余额重复用于测算。")
            }
            Section("收入口径") {
                Text("统一按税前计算。每个发薪日按当天情景计入对应月薪，暂不处理工资所属月份、离职结薪或不足整月工资的追溯。灵活收入同样按到账日所在情景计入。")
                Text("理财收益留在理财中，沿用财富的单利或每满 365 天复投规则。赎回先使用未复投收益，再使用本金，已取出的资金不再计息。")
            }
            Section("生存结果") {
                Text("全部可用资金不足以支付到期支出的首日为终点。系统最多推算 100 年；未找到终点时显示至少可生存的时长，而非宣称无限生存。")
                Text("只有无债务、稳定工资、灵活收入及理财收益覆盖全部计划的年度支出上界，且现金缓冲达到该上界两倍时，才提前判定可持续生存。其他情况继续推算。")
            }
            Section("数据来源") {
                Text("生活支出直接读取日常开支记录；还款只读取负债的还款安排，不再叠加财富页面汇总值。未计入通胀、股价变化、未来未登记的股票归属及未登记消费。")
            }
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
                }
            }
        }.navigationTitle("收支明细").navigationBarTitleDisplayMode(.inline)
    }
}
