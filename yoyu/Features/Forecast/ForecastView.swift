import SwiftUI
import SwiftData

struct ForecastView: View {
    var isExample = false
    @Query private var expenses: [RecurringExpense]
    @Query private var liabilities: [LiabilityAccount]
    @Query private var profiles: [UserProfile]
    @Query private var jobs: [Employment]
    @Query private var salaries: [SalaryStage]
    @Query private var scenarios: [ForecastScenarioRecord]
    @Environment(CareerClock.self) private var clock
    @State private var duration = 12
    @State private var editing = false
    @State private var fullscreen = false
    @State private var balanceMode = true
    private var origin: Date { ScenarioForecast.origin(after: clock.now) }
    private var saved: ForecastScenarioRecord? { ForecastScenarioStore.current(scenarios) }
    private var profile: UserProfile? { profiles.max { $0.updatedAt(for: .wealth) < $1.updatedAt(for: .wealth) } }
    private var grossSalary: Int64? { CareerRules.current(jobs, on: clock.now).flatMap { CareerRules.salary(salaries, for: $0, on: clock.now)?.salaryCents } }
    private var draftScenario: ForecastScenario { saved?.scenario ?? ForecastScenario(origin: origin) }
    private var scenario: ForecastScenario {
        var value = draftScenario
        value.openingFunds = profile?.cashCents
        value.fundsMonth = origin
        return value
    }
    private var corruptScenario: Bool { saved != nil && saved?.scenario == nil }
    private var months: [ScenarioForecastMonth] {
        ScenarioForecast.months(scenario: scenario, expenses: expenses, liabilities: liabilities, after: clock.now, count: duration, investmentValue: profile?.investmentCents == nil ? nil : { profile?.investmentValue(on: $0) })
    }
    private var paused: [RecurringExpense] { ExpenseRules.records(expenses).filter { $0.plan?.pausesDuringWorkBreak == true } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isExample {
                        Label("情景演示 · 示例资金和开支", systemImage: "sparkles")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    NavigationLink { ForecastPrototypeView() } label: {
                        Label("新版预测 · 交互原型", systemImage: "sparkles")
                            .frame(maxWidth: .infinity, alignment: .leading).dashboardCard()
                    }.buttonStyle(.plain)
                    scenarioCard
                    sourceSummary
                    let values = months
                    if corruptScenario {
                        Label("已保存的情景暂时无法读取，请重新调整情景。", systemImage: "exclamationmark.triangle")
                    } else {
                        runway(values)
                        Picker("预测范围", selection: $duration) {
                            Text("未来 12 个月").tag(12)
                            Text("3 年").tag(36)
                            Text("5 年").tag(60)
                        }.pickerStyle(.segmented).accessibilityIdentifier("forecast.range")
                        if scenario.mode == .temporaryBreak,
                           scenario.returnDate >= ProfileRules.calendar.date(byAdding: .month, value: duration, to: origin)! {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("预计再就业时间在当前展示范围之后。")
                                if duration < 60 { Button("查看更长时间") { duration = duration == 12 ? 36 : 60 } }
                            }.font(.subheadline)
                        }
                        trend(values)
                        expenseOverview(values)
                        NavigationLink { ScenarioMonthList(months: values, scenario: scenario) } label: {
                            HStack {
                                Label("查看逐月明细", systemImage: "calendar")
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.bold())
                            }.dashboardCard()
                        }.buttonStyle(.plain).accessibilityIdentifier("forecast.details")
                        assumptions
                    }
                }.padding(DashboardStyle.pageInset)
            }
            .background(DashboardStyle.background)
            .dashboardTabRoot(title: "预测")
            .sheet(isPresented: $editing) { ForecastScenarioEditor(scenario: draftScenario, origin: origin, records: scenarios, cash: profile?.cashCents, grossSalary: grossSalary, investment: profile?.investmentValue(on: origin)) }
            .fullScreenCover(isPresented: $fullscreen) { fullscreenChart(months) }
        }
    }

    private var sourceSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("从今天的财务状况出发", systemImage: "link").font(.subheadline.weight(.semibold))
            HStack {
                metric("现金 · 关联财富", value: money(profile?.cashCents))
                Spacer()
                metric("理财估值 · 关联财富", value: money(profile?.investmentValue(on: origin)))
            }
            if let updated = profile?.wealthUpdatedAt {
                Text("财富记录更新于 \(ExpenseRules.dateLabel(updated))，请确认余额仍适用于今天。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("先累计中断工作前的工资与收支，再切换到所选情景。理财估值不直接算作可用现金。")
                .font(.caption).foregroundStyle(.secondary)
            if profile?.investmentCents != nil && (profile?.investmentAnnualReturnBasisPoints == nil || profile?.investmentRegistrationDate == nil) {
                Text("理财收益率或登记日期待补充，目前仅沿用本金。")
                    .font(.caption).foregroundStyle(.orange)
            }
        }.dashboardCard()
    }
    private var scenarioCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("工作情景", systemImage: scenario.mode.icon).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button("调整情景") { editing = true }.font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44).accessibilityIdentifier("forecast.editScenario")
            }
            Text(scenario.mode.title).font(.title2.bold()).accessibilityIdentifier("forecast.scenarioTitle")
            if scenario.mode == .employed {
                Text("按当前月到手收入与已有开支计划推算。")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("\(ExpenseRules.dateLabel(scenario.breakStart)) 起中断工作")
                    .font(.subheadline).foregroundStyle(.secondary)
                if scenario.mode == .temporaryBreak {
                    HStack(alignment: .top, spacing: 20) {
                        metric("预计再就业", value: ExpenseRules.dateLabel(scenario.returnDate))
                        metric("再就业月到手", value: money(scenario.returnIncome))
                    }
                } else {
                    Text("预测期内不再计入工作收入").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.dashboardCard()
    }
    private func runway(_ values: [ScenarioForecastMonth]) -> some View {
        let complete = values.allSatisfy { $0.balance != nil }
        let firstShortfall = values.first { ($0.balance ?? 0) < 0 }
        return VStack(alignment: .leading, spacing: 16) {
            Label("资金能撑多久", systemImage: "shield.lefthalf.filled")
                .font(.subheadline).foregroundStyle(.secondary)
            if complete {
                if let shortfall = firstShortfall {
                    Text("\(ExpenseRules.monthLabel(shortfall.date))").font(.title2.bold())
                        .accessibilityIdentifier("forecast.runway")
                    Text("预计首次月末资金不足 · 缺口 \(money(shortfall.balance.map { -$0 }))")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("预测期内资金充足").font(.title2.bold()).accessibilityIdentifier("forecast.runway")
                    Text("按已录入计划，未来 \(duration) 个月的预计月末余额均不低于零。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                Text("补充后可测算").font(.title2.bold()).accessibilityIdentifier("forecast.runway")
                Text(missingReason(values)).font(.subheadline).foregroundStyle(.secondary)
                Button("补充计算基础") { editing = true }.font(.subheadline.weight(.semibold))
            }
            if expenses.isEmpty && liabilities.isEmpty {
                Text("尚未配置开支，测算未包含生活成本。")
                    .font(.caption).foregroundStyle(.orange)
            } else if ExpectedExpenseRules.missingBills(liabilities) {
                Text("部分账单未填写，资金结论仅覆盖已知支出。")
                    .font(.caption).foregroundStyle(.orange)
            }
            Divider()
            HStack(alignment: .top) {
                if scenario.mode == .temporaryBreak {
                    let before = values.filter { $0.date < ExpenseRules.month(scenario.returnDate) }
                    let minimum = complete ? ([scenario.openingFunds].compactMap { $0 } + before.compactMap(\.balance)).min() : nil
                    metric("再就业前月末低点¹", value: money(minimum))
                } else {
                    metric("期末预计余额", value: complete ? money(values.last?.balance) : "待补充")
                }
                Spacer(minLength: 12)
                let gapCosts = values.map(\.breakExpense)
                let gapTotal = gapCosts.contains(where: { $0 == nil }) ? nil : LiabilityRules.sum(gapCosts.compactMap { $0 })
                metric(scenario.mode == .employed ? "期初可用资金" : "中断期间支出²", value: money(scenario.mode == .employed ? (ProfileRules.calendar.isDate(scenario.fundsMonth, inSameDayAs: origin) ? scenario.openingFunds : nil) : gapTotal))
            }
            Text("仅按月度现金流估算，不保证月内每一天的资金充足。")
                .font(.caption).foregroundStyle(.secondary)
        }.dashboardCard(highlighted: true)
    }
    private func missingReason(_ values: [ScenarioForecastMonth]) -> String {
        if scenario.openingFunds == nil || !ProfileRules.calendar.isDate(scenario.fundsMonth, inSameDayAs: origin) { return "请先在财富中补充现金余额；预测会自动关联，无需重复录入。" }
        if values.contains(where: { $0.income == nil }) { return "当前或再就业后的月到手收入尚未填写，暂不按零收入计算。" }
        return "部分开支或计算结果无法读取，请核对计划和金额。"
    }
    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
    }
    private func money(_ value: Int64?) -> String { value.map { ProfileRules.money($0) } ?? "待补充" }
    private func expenseOverview(_ values: [ScenarioForecastMonth]) -> some View {
        let costs = values.map(\.expense)
        return VStack(alignment: .leading, spacing: 14) {
            Text("这段时间的开支").font(.headline)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("预计总支出").font(.caption).foregroundStyle(.secondary)
                    Text(money(ExpenseForecast.total(costs))).font(.title2.bold()).monospacedDigit()
                        .accessibilityIdentifier("forecast.total")
                }
                Spacer()
                metric("平均每月", value: money(ExpenseForecast.total(costs).map { $0 / Int64(costs.count) }))
            }
            NavigationLink {
                List {
                    if paused.isEmpty { Text("还没有设置随工作中断暂停的开支。") }
                    ForEach(paused) { record in
                        NavigationLink(record.plan?.name ?? "待核对") { ExpenseDetailView(recordID: record.id) }
                    }
                }.navigationTitle("随工作中断暂停").navigationBarTitleDisplayMode(.inline)
            } label: {
                HStack {
                    Text("工作中断期间暂停的开支 · \(paused.count) 项")
                    Spacer(); Image(systemName: "chevron.right").font(.caption)
                }.font(.subheadline)
            }
            if expenses.isEmpty && liabilities.isEmpty {
                Text("尚未配置开支，当前零支出不代表没有生活成本。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if ExpectedExpenseRules.missingBills(liabilities) {
                Text("部分信用卡账单未填写，结果仅包含已知还款。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.dashboardCard()
    }
    private func trend(_ values: [ScenarioForecastMonth]) -> some View {
        let canPlot = values.allSatisfy { balanceMode ? $0.balance != nil : $0.expense.total != nil }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("未来的资金变化").font(.headline)
                Spacer()
                Button { fullscreen = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("全屏查看趋势").accessibilityIdentifier("forecast.expand").disabled(!canPlot)
            }
            Picker("图表内容", selection: $balanceMode) {
                Text("资金余额").tag(true); Text("每月收支").tag(false)
            }.pickerStyle(.segmented).accessibilityIdentifier("forecast.chartMode")
            if canPlot {
                ScenarioForecastChart(months: values, scenario: scenario, balanceMode: balanceMode).frame(height: 210)
                chartNote
            } else {
                Text(balanceMode ? "补充资金与收入后，查看余额走势；也可以切换到每月收支先看开支。" : "部分开支无法计算，请核对已有计划。")
                    .font(.subheadline).foregroundStyle(.secondary).frame(minHeight: 110)
            }
        }.dashboardCard()
    }
    private var chartNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            if scenario.mode != .employed {
                Text("浅橙色区域为工作中断阶段；橙线为中断开始，绿线为再就业。")
            }
            Text(balanceMode ? "显示期初资金与每个月末的预计余额。" : "按月份计入，年付不摊平；未填写的收入不绘制。")
        }.font(.caption).foregroundStyle(.secondary)
    }
    private func fullscreenChart(_ values: [ScenarioForecastMonth]) -> some View {
        GeometryReader { geometry in
            let rotated = geometry.size.height > geometry.size.width
            let canvas = CGSize(width: rotated ? geometry.size.height : geometry.size.width, height: rotated ? geometry.size.width : geometry.size.height)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(scenario.mode.title) · \(balanceMode ? "资金余额" : "每月收支")").font(.headline)
                        Text("\(duration == 12 ? "未来 12 个月" : "未来 \(duration / 12) 年") · \(ExpenseRules.monthLabel(origin)) 起")
                            .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("forecast.fullscreen.range")
                    }
                    Spacer()
                    Button { fullscreen = false } label: { Image(systemName: "xmark").frame(width: 44, height: 44).background(.secondary.opacity(0.1), in: Circle()) }
                        .buttonStyle(.plain).accessibilityLabel("关闭全屏图表").accessibilityIdentifier("forecast.fullscreen.close")
                }
                ScenarioForecastChart(months: values, scenario: scenario, balanceMode: balanceMode)
                chartNote
            }.padding(.horizontal, 24).padding(.vertical, 12)
                .frame(width: canvas.width, height: canvas.height).rotationEffect(.degrees(rotated ? 90 : 0))
                .frame(width: geometry.size.width, height: geometry.size.height)
        }.background(DashboardStyle.background.ignoresSafeArea()).statusBarHidden().persistentSystemOverlays(.hidden)
    }
    private var assumptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("这份预测如何计算").font(.subheadline.weight(.semibold))
            Text("从 \(ExpenseRules.dateLabel(origin)) 起推算，本月仅计入今天及之后的收支。自动沿用财富中最新记录的现金，请保持余额更新。工资按自然日折算，不等同实际发薪日；失业开始前照常计入。理财估值变化单独展示，指定赎回时才将本息转入现金。未计入补偿金、失业金、奖金、未来涨价或未记录消费。负债还款包含本金和利息／费用。")
            Text("¹ 包含期初资金及再就业月份之前的月末余额，不代表再就业当天余额。² 仅汇总当前预测范围内、工作中断日期之间的支出。")
            NavigationLink("查看和调整已有开支计划") { ExpectedExpenseView() }.font(.subheadline)
        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
    }
}

private struct ScenarioMonthList: View {
    let months: [ScenarioForecastMonth]
    let scenario: ForecastScenario
    var body: some View {
        List {
            Section {
                ForEach(months) { month in
                    NavigationLink { ScenarioMonthDetail(month: month, scenario: scenario) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(ExpenseRules.monthLabel(month.date)).font(.headline)
                                Spacer(); Text(month.workStatus).font(.caption).foregroundStyle(.secondary)
                            }
                            Text("收入 \(money(month.income)) · 支出 \(money(month.expense.total))").font(.caption).foregroundStyle(.secondary)
                            Text("月末余额 \(money(month.balance))").font(.subheadline).monospacedDigit()
                        }.padding(.vertical, 5)
                    }
                }
            } footer: { Text("沿用当前情景；负数表示资金缺口，待补充表示尚不能完整计算。") }
        }.neutralPageBackground().navigationTitle("逐月明细").navigationBarTitleDisplayMode(.inline)
    }
    private func money(_ value: Int64?) -> String { value.map { ProfileRules.money($0) } ?? "待补充" }
}

private struct ScenarioMonthDetail: View {
    let month: ScenarioForecastMonth
    let scenario: ForecastScenario
    @Query private var expenses: [RecurringExpense]
    @Query private var liabilities: [LiabilityAccount]
    var body: some View {
        List {
            Section {
                LabeledContent("工作状态", value: month.workStatus)
                LabeledContent("现金流入（含赎回）", value: money(month.income))
                LabeledContent("其中理财赎回本息", value: money(month.redemption))
                LabeledContent("理财估值变化（非现金收入）", value: money(month.investmentGain))
                LabeledContent("预计支出", value: money(month.expense.total))
                LabeledContent("月末余额", value: money(month.balance))
            } header: { Text(scenario.mode.title) } footer: { Text("收入按本月在职天数折算；金额沿用进入明细时的情景。") }
            Section("日常开支") {
                ForEach(ExpenseRules.records(expenses)) { record in
                    if let plan = record.plan {
                        NavigationLink { ExpenseDetailView(recordID: record.id) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                LabeledContent(plan.name, value: money(ExpenseRules.amount(plan, in: month.date, workBreaks: scenario.workBreaks, from: month.calculationStart)))
                                if plan.pausesDuringWorkBreak == true { Text("已按工作中断阶段扣除暂停部分").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    } else { Text("一项开支无法读取，请核对原计划。") }
                }
            }
            Section("负债还款 · 不随工作中断暂停") {
                ForEach(LiabilityRules.accounts(liabilities)) { account in
                    NavigationLink { LiabilityDetailView(accountID: account.id) } label: {
                        LabeledContent(account.name, value: money(ExpectedExpenseRules.repayment(account, in: month.date, from: month.calculationStart)))
                    }
                }
            }
        }.neutralPageBackground().navigationTitle(ExpenseRules.monthLabel(month.date)).navigationBarTitleDisplayMode(.inline)
    }
    private func money(_ value: Int64?) -> String { value.map { ProfileRules.money($0) } ?? "待补充" }
}
#if DEBUG
struct ForecastTestHost: View {
    @State private var container: ModelContainer?
    @State private var clock = CareerClock()
    var body: some View {
        Group {
            if let container {
                TabView { Tab("预测", systemImage: "chart.xyaxis.line") {
                    ForecastView(isExample: true).tint(DashboardStyle.accent)
                } }
                    .tint(DashboardStyle.tabSelection).modelContainer(container).environment(clock).environment(\.locale, Locale(identifier: "zh_CN"))
            } else { ProgressView().task { prepare() } }
        }
    }
    private func prepare() {
        do {
            let schema = Schema([RecurringExpense.self, LiabilityAccount.self, ForecastScenarioRecord.self, UserProfile.self, Employment.self, SalaryStage.self])
            let sample = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
            clock.now = ProcessInfo.processInfo.arguments.contains("--scenario-demo")
                ? ProfileRules.date(2026, 9, 22) : ProfileRules.date(2026, 10, 1)
            let plans = [
                ExpensePlan(name: "生活费", amount: 3000_00, start: ProfileRules.date(2026, 9, 1)),
                ExpensePlan(name: "租金", amount: 2000_00, start: ProfileRules.date(2026, 9, 1), end: ProfileRules.date(2027, 3, 31)),
                ExpensePlan(name: "年度保险", amount: 6000_00, frequency: .yearly, start: ProfileRules.date(2026, 12, 10), spreadAcrossMonth: false, dueDay: 10)
            ]
            for plan in plans {
                let record = RecurringExpense()
                record.planData = try JSONEncoder().encode(plan)
                sample.mainContext.insert(record)
            }
            var scenario = ForecastScenario(origin: ScenarioForecast.origin(after: clock.now))
            scenario.currentIncome = 15000_00
            scenario.returnIncome = 12000_00
            scenario.openingFunds = 100000_00
            if ProcessInfo.processInfo.arguments.contains("--scenario-ui-test") || ProcessInfo.processInfo.arguments.contains("--scenario-demo") {
                scenario.openingFunds = 20000_00
                let commute = RecurringExpense()
                commute.planData = try JSONEncoder().encode(ExpensePlan(name: "通勤与工作餐", amount: 600_00, start: ProfileRules.date(2026, 9, 1), pausesDuringWorkBreak: true))
                sample.mainContext.insert(commute)
            }
            if ProcessInfo.processInfo.arguments.contains("--scenario-demo") { scenario.mode = .temporaryBreak }
            let profile = UserProfile()
            profile.cashCents = scenario.openingFunds
            profile.investmentCents = 100000_00
            profile.investmentAnnualReturnBasisPoints = 300
            profile.investmentRegistrationDate = clock.now
            sample.mainContext.insert(profile)
            if ProcessInfo.processInfo.arguments.contains("--scenario-demo") {
                scenario.breakStart = ProfileRules.date(2026, 12, 22)
                scenario.returnDate = ProfileRules.date(2027, 3, 22)
            }
            let fixture = ForecastScenarioRecord()
            fixture.data = try JSONEncoder().encode(scenario)
            sample.mainContext.insert(fixture)
            try sample.mainContext.save()
            container = sample
        } catch { assertionFailure("Forecast fixture failed: \(error)") }
    }
}
#endif
