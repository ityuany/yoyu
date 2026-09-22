import SwiftUI
import SwiftData

struct SeveranceScenario {
    let job: Employment?
    let settings: SeveranceSettings?
    let salaryCents: Int64?
    let noticeSalaryCents: Int64?
    let estimate: SeveranceRules.Estimate?

    init(jobs: [Employment], stages: [SalaryStage], now: Date) {
        let current = CareerRules.current(jobs, on: now)
        job = current
        settings = current.flatMap { SeveranceRules.settings(for: $0)?.automatic }
        salaryCents = current.flatMap { SeveranceRules.averageSalary(stages: stages, job: $0, on: now) }
        noticeSalaryCents = current.flatMap { SeveranceRules.previousMonthSalary(stages: stages, job: $0, on: now) }
        if let current, let settings {
            estimate = SeveranceRules.estimate(settings: settings, job: current, salaryCents: salaryCents, noticeSalaryCents: noticeSalaryCents, on: now)
        } else {
            estimate = nil
        }
    }

    func estimate(for plan: SeverancePlan, on date: Date) -> SeveranceRules.Estimate? {
        guard let job, var settings else { return nil }
        settings.plan = plan
        return SeveranceRules.estimate(settings: settings, job: job, salaryCents: salaryCents,
                                      noticeSalaryCents: noticeSalaryCents, on: date)
    }

}

struct SeveranceDetailView: View {
    @Query private var jobs: [Employment]
    @Query private var stages: [SalaryStage]
    @Environment(CareerClock.self) private var clock
    @State private var editing = false

    private var scenario: SeveranceScenario { SeveranceScenario(jobs: jobs, stages: stages, now: clock.now) }
    var body: some View {
        List {
            if let job = scenario.job {
                Section("预计补偿（税前）") {
                    AdaptiveValueRow(title: "预测方案", value: scenario.settings?.plan.title ?? "待配置")
                    AdaptiveValueRow(title: "预测补偿", value: ProfileRules.money(scenario.estimate?.amountCents))
                    ForEach(SeverancePlan.selectable) { plan in
                        AdaptiveValueRow(title: "补偿方案 \(plan.title)",
                                         value: scenario.estimate(for: plan, on: clock.now).map { ProfileRules.money($0.amountCents) } ?? "待完善")
                    }
                }

                Section("自动测算依据") {
                    let baseEstimate = scenario.estimate(for: .n, on: clock.now)
                    AdaptiveValueRow(title: "当前企业", value: job.displayName)
                    AdaptiveValueRow(title: "测算日期", value: "今天 · \(CareerRules.dateLabel(clock.now))")
                    AdaptiveValueRow(title: "工龄折算", value: SeveranceRules.tenureHundredths(start: job.start, on: clock.now).map { ProfileRules.input($0) + " 年" } ?? "待补全入职日期")
                    AdaptiveValueRow(title: "平均月薪", value: ProfileRules.money(scenario.salaryCents))
                    AdaptiveValueRow(title: "上月工资", value: ProfileRules.money(scenario.noticeSalaryCents))
                    AdaptiveValueRow(title: "3倍社平", value: scenario.settings?.tripleAverageSalaryCents.map { ProfileRules.money($0) } ?? "待设置，暂未应用封顶")
                    AdaptiveValueRow(title: "实际采用月薪基数", value: ProfileRules.money(baseEstimate?.baseSalaryCents))
                    AdaptiveValueRow(title: "实际采用补偿年限", value: baseEstimate?.tenureHundredths.map { ProfileRules.input($0) + " 年" } ?? "待完善")
                    if baseEstimate?.isDoubleCapped == true {
                        Text("已应用双封顶：基数按三倍社平，补偿年限最多 12 年。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    if scenario.salaryCents == nil || scenario.noticeSalaryCents == nil || job.start == nil {
                        Text("测算资料不足，请补充当前企业的入职日期及覆盖计算期间的薪资记录。")
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink("查看职业履历") { CareerView(destination: .history) }
                }

                Section {
                    Text("假设今天被裁员，N 按 N × 月薪基数计算，N+1 再加额外一个月工资，2N 按 N × 月薪基数 × 2 计算。N 按本企业整年工龄及余期估算：不足半年计 0.5，满半年计 1。")
                    Text("自动基数按本企业最近 12 个完整自然月的薪资阶段估算：税前月薪加年终奖月均分摊，不含股票。未填奖金按 0 计；不足 12 个月按实际任职月数，零月按日折算。缺少历史薪资时请补充职业履历。额外一个月单独按上月月薪估算。")
                    Text("平均月工资高于已设置的3倍社平时，工资基数与 12 年补偿年限同时封顶；未超过时不套用该年限上限。N+1 的额外一个月单独计算，2N 按本页 N 的两倍估算。")
                    Text("三倍社平采用当地上年度公布的职工月平均工资标准，年度变化需更新设置。当前为情景估算，未自动处理最低工资、2008 年前工龄分段、地区差异及税费。补偿尚未到账，不计入已记录资产。")
                    Link("劳动合同法", destination: URL(string: "https://www.mohrss.gov.cn/xxgk2020/fdzdgknr/zcfg/fl/202011/t20201102_394622_wap.html")!)
                    Link("劳动合同法实施条例", destination: URL(string: "https://www.mohrss.gov.cn/xxgk2020/fdzdgknr/zcfg/fg/202011/t20201103_394939_wap.html")!)
                } header: {
                    Text("计算口径")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
                Section {
                    ContentUnavailableView("当前任职待完善", systemImage: "building.2", description: Text("补偿测算需要一段明确的当前任职。"))
                    NavigationLink("管理企业履历") { CareerView(destination: .history) }
                }
            }
        }.neutralPageBackground()
        .navigationTitle("补偿")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if scenario.job != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("补偿设置") { editing = true }
                }
            }
        }
        .sheet(isPresented: $editing) {
            if let job = scenario.job {
                SeveranceEditor(job: job, settings: scenario.settings ?? SeveranceSettings())
            }
        }
    }
}

#if DEBUG
struct SeveranceTestHost: View {
    private let container: ModelContainer
    private let clock = CareerClock()

    init() {
        let schema = Schema([UserProfile.self, WorkdayOverride.self, Employment.self, SalaryStage.self,
                             StockHolding.self, LiabilityAccount.self, RecurringExpense.self])
        container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        clock.now = ProfileRules.calendar.date(from: DateComponents(year: 2026, month: 9, day: 22))!
        let job = Employment()
        job.name = "补偿测试企业"
        job.start = ProfileRules.calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        let salary = SalaryStage()
        salary.employmentID = job.id
        salary.effectiveDate = job.start
        salary.salaryCents = 2_000_000
        container.mainContext.insert(job)
        container.mainContext.insert(salary)
        try! container.mainContext.save()
    }

    var body: some View {
        WealthView()
            .modelContainer(container)
            .environment(clock)
            .environment(AppNavigation())
            .environment(\.locale, Locale(identifier: "zh_CN"))
    }
}
#endif
