import SwiftUI
import SwiftData

struct SeveranceScenario {
    let job: Employment?
    let settings: SeveranceSettings?
    let salaryCents: Int64?
    let estimate: SeveranceRules.Estimate?

    init(jobs: [Employment], stages: [SalaryStage], now: Date) {
        let current = CareerRules.current(jobs, on: now)
        job = current
        settings = current.flatMap { SeveranceRules.settings(for: $0) }
        salaryCents = current.flatMap { CareerRules.salary(stages, for: $0, on: now)?.salaryCents }
        if let current, let settings {
            estimate = SeveranceRules.estimate(settings: settings, job: current, salaryCents: salaryCents, on: now)
        } else {
            estimate = nil
        }
    }

    var subtitle: String {
        guard job != nil else { return "当前任职待完善" }
        guard let settings else { return "补偿方案需重新设置" }
        guard estimate != nil else { return "\(settings.plan.title) · 测算资料待补全" }
        if settings.plan == .customAmount { return "自定义金额 · 税前" }
        let usesSalary = settings.baseSalaryCents == nil || (settings.plan == .nPlusOne && settings.noticeSalaryCents == nil)
        return "\(settings.plan.title) · \(usesSalary ? "暂按当前月薪" : "自定工资基数") · 税前"
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
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("预计补偿（税前）").font(.subheadline).foregroundStyle(.secondary)
                        DashboardAmount(value: scenario.estimate.map { ProfileRules.money($0.amountCents) } ?? "待完善")
                        Text(scenario.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("测算方案") {
                    AdaptiveValueRow(title: "当前企业", value: job.displayName)
                    AdaptiveValueRow(title: "测算日期", value: CareerRules.dateLabel(clock.now))
                    if let settings = scenario.settings {
                        AdaptiveValueRow(title: "补偿方式", value: settings.plan.title)
                        if settings.plan != .customAmount {
                            AdaptiveValueRow(title: "补偿年限 N", value: (settings.tenureHundredths ?? SeveranceRules.tenureHundredths(start: job.start, on: clock.now)).map { ProfileRules.input($0) } ?? "待补全入职日期")
                            AdaptiveValueRow(title: "N 的月薪基数", value: ProfileRules.money(settings.baseSalaryCents ?? scenario.salaryCents))
                            if settings.plan == .nPlusOne {
                                AdaptiveValueRow(title: "额外 1 个月工资", value: ProfileRules.money(settings.noticeSalaryCents ?? scenario.salaryCents))
                            }
                        }
                    }
                }

                Section {
                    Text("假设今天被裁员，N 按 N × 月薪基数计算，N+1 再加额外一个月工资，2N 按 N × 月薪基数 × 2 计算。N 按本企业整年工龄及余期估算：不足半年计 0.5，满半年计 1。")
                    Text("工资默认参考当前税前月薪。经济补偿通常采用离职前 12 个月应得平均工资，额外一个月采用上月工资。所选补偿方式为测算假设，具体以适用情形及协商方案为准。")
                    Text("未自动处理当地工资封顶、最低工资、2008 年前工龄及税费，可按实际方案调整。预计补偿已计入总资产，尚未到账。")
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
                    Button("编辑") { editing = true }
                }
            }
        }
        .sheet(isPresented: $editing) {
            if let job = scenario.job {
                SeveranceEditor(job: job, settings: scenario.settings ?? SeveranceSettings(), salaryCents: scenario.salaryCents)
            }
        }
    }
}
