import SwiftUI
import SwiftData

struct SeveranceDetailView: View {
    @Query private var jobs: [Employment]
    @Query private var stages: [SalaryStage]
    @Query private var bonuses: [BonusPayment]
    @Environment(CareerClock.self) private var clock
    @State private var editing = false

    // 财富按当前日期估算；分析中的失业日期只用于预测。
    private var compensationDate: Date { clock.now }
    private var scenario: SeveranceScenario { SeveranceScenario(jobs: jobs, stages: stages, bonuses: bonuses, now: compensationDate, employmentDate: clock.now) }
    var body: some View {
        List {
            if let job = scenario.job {
                Section("预计补偿（税前）") {
                    AdaptiveValueRow(title: "预测方案", value: scenario.settings?.plan.title ?? "待配置")
                    AdaptiveValueRow(title: "预测补偿", value: ProfileRules.money(scenario.estimate?.amountCents))
                    ForEach(SeverancePlan.selectable) { plan in
                        AdaptiveValueRow(title: "补偿方案 \(plan.title)",
                                         value: scenario.estimate(for: plan, on: compensationDate).map { ProfileRules.money($0.amountCents) } ?? "待完善")
                    }
                }.listRowBackground(AppTheme.cardBackground)

                Section("自动测算依据") {
                    let baseEstimate = scenario.estimate(for: .n, on: compensationDate)
                    AdaptiveValueRow(title: "当前企业", value: job.displayName)
                    AdaptiveValueRow(title: "测算日期", value: CareerRules.dateLabel(compensationDate))
                    AdaptiveValueRow(title: "工龄折算", value: SeveranceRules.tenureHundredths(start: job.start, on: compensationDate).map { ProfileRules.input($0) + " 年" } ?? "待补全入职月份")
                    AdaptiveValueRow(title: "平均月薪", value: ProfileRules.money(scenario.salaryCents))
                    AdaptiveValueRow(title: "上月工资", value: ProfileRules.money(scenario.noticeSalaryCents))
                    AdaptiveValueRow(title: "3倍社平", value: scenario.settings?.tripleAverageSalaryCents.map { ProfileRules.money($0) } ?? "待设置，暂未应用封顶")
                    AdaptiveValueRow(title: "实际采用月薪基数", value: ProfileRules.money(baseEstimate?.baseSalaryCents))
                    AdaptiveValueRow(title: "实际采用补偿年限", value: baseEstimate?.tenureHundredths.map { ProfileRules.input($0) + " 年" } ?? "待完善")
                    if baseEstimate?.isDoubleCapped == true {
                        Text("已应用双封顶：基数按三倍社平，补偿年限最多 12 年。")
                            .font(.footnote).foregroundStyle(AppTheme.secondaryText)
                    }
                }.listRowBackground(AppTheme.cardBackground)
                Section {
                    if scenario.salaryCents == nil || scenario.noticeSalaryCents == nil || job.start == nil {
                        Text("测算资料不足，请补充当前企业的入职月份及覆盖计算期间的薪资记录。")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    NavigationLink("查看职业履历") { CareerView(destination: .history) }
                }.listRowBackground(AppTheme.cardBackground)

                Section {
                    Text("按测算日期被裁员估算，N 按 N × 月薪基数计算，N+1 再加额外一个月工资，2N 按 N × 月薪基数 × 2 计算。N 按本企业整年工龄及余期估算：不足半年计 0.5，满半年计 1。")
                    Text("自动基数按本企业最近 12 个完整自然月的税前月薪与期间实际收到的税前年终奖估算，不含股票。未确认年份的旧年终奖暂不计入；不足 12 个月按实际任职月数，零月按日折算。额外一个月单独按上月月薪估算。")
                    Text("平均月工资高于已设置的3倍社平时，工资基数与 12 年补偿年限同时封顶；未超过时不套用该年限上限。N+1 的额外一个月单独计算，2N 按本页 N 的两倍估算。")
                    Text("三倍社平采用当地上年度公布的职工月平均工资标准，年度变化需更新设置。当前为情景估算，未自动处理最低工资、2008 年前工龄分段、地区差异及税费。补偿尚未到账，不计入已记录资产。")
                    Link("劳动合同法", destination: URL(string: "https://www.mohrss.gov.cn/xxgk2020/fdzdgknr/zcfg/fl/202011/t20201102_394622_wap.html")!)
                    Link("劳动合同法实施条例", destination: URL(string: "https://www.mohrss.gov.cn/xxgk2020/fdzdgknr/zcfg/fg/202011/t20201103_394939_wap.html")!)
                } header: {
                    Text("计算口径")
                }.listRowBackground(AppTheme.cardBackground)
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
            } else {
                Section {
                    ContentUnavailableView("当前任职待完善", systemImage: "building.2", description: Text("补偿测算需要一段明确的当前任职。"))
                    NavigationLink("管理企业履历") { CareerView(destination: .history) }
                }.listRowBackground(AppTheme.cardBackground)
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
