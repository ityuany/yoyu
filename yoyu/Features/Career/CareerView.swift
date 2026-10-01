import SwiftUI
import SwiftData

struct CareerView: View {
    let destination: CareerDestination
    @Query private var jobs: [Employment]
    @Environment(CareerClock.self) private var clock
    @Query private var stages: [SalaryStage]
    @State private var adding = false
    @State private var selectedEmployment: String?

    private var job: Employment? {
        switch destination {
        case .employment(let id):
            return CareerRules.employments(jobs).first { $0.id == id }
        default: break
        }
        return CareerRules.current(jobs, on: clock.now)
    }
    var body: some View {
        Group {
            if destination == .review {
                CareerReviewView()
            } else if destination == .pension || destination == .housing {
                ContributionAnalysisOverview(jobs: jobs, kind: destination == .pension ? .pension : .housing)
            } else if destination == .history {
                List {
                    Section {
                        NavigationLink(value: CareerDestination.review) {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("职业回顾")
                                    Text("薪资变化与任职时长").font(.caption).foregroundStyle(AppTheme.secondaryText)
                                }
                            } icon: {
                                Image(systemName: "chart.xyaxis.line").foregroundStyle(DashboardStyle.accent)
                            }
                        }
                    }.listRowBackground(AppTheme.cardBackground)
                    if jobs.isEmpty { ContentUnavailableView("尚未录入企业履历", systemImage: "building.2", description: Text("添加当前任职，或补录过去的企业经历。")) }
                    let ordered = CareerRules.employments(jobs)
                    let current = ordered.filter { $0.isCurrent(on: clock.now) }
                    if current.count > 1 {
                        Text("有多段任职尚未结束，请完善离职月份后确定当前企业。")
                            .foregroundStyle(AppTheme.warning)
                    }
                    if !ordered.isEmpty {
                        Section("任职时间线") {
                            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, job in
                                let trend = salaryTrend(at: index, in: ordered)
                                row(job, isFirst: index == 0, isLast: index == ordered.count - 1,
                                    trend: trend,
                                    nextTrend: index + 1 < ordered.count ? salaryTrend(at: index + 1, in: ordered) : nil)
                            }
                        }.listRowBackground(AppTheme.cardBackground)
                    }
                }.neutralPageBackground()
                .listStyle(.insetGrouped)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .listSectionSpacing(.custom(12))
                .navigationTitle("企业履历")
                .toolbar { ToolbarItem(placement: .primaryAction) { Button("添加", systemImage: "plus") { adding = true } } }
            } else if let job {
                switch destination {
                case .salary: SalaryTimelineView(job: job)
                case .work: EmploymentWorkDetail(job: job)
                default: EmploymentDetailOverview(job: job)
                }
            } else {
                ContentUnavailableView {
                    Label(jobs.isEmpty ? "企业信息待完善" : "暂无可用的当前任职", systemImage: "building.2")
                } actions: {
                    NavigationLink("管理企业履历", value: CareerDestination.history)
                }
                .navigationTitle(destination == .work ? "工作安排" : "薪资待遇")
            }
        }
        #if os(iOS)
        .toolbar(.visible, for: .navigationBar)
        #endif
        .sheet(isPresented: $adding) { EmploymentEditor(job: nil) }
        .navigationDestination(item: $selectedEmployment) { id in
            CareerView(destination: .employment(id))
        }
    }
    private func salaryTrend(at index: Int, in ordered: [Employment]) -> EmploymentSalaryTrend {
        let current = ordered[index].start.flatMap {
            CareerRules.salary(stages, for: ordered[index], on: $0)?.salaryCents
        }
        let previous = index + 1 < ordered.count
            ? CareerRules.salary(stages, for: ordered[index + 1], on: clock.now)?.salaryCents
            : nil
        return EmploymentSalaryTrend(current: current, previous: previous)
    }

    private func row(_ job: Employment, isFirst: Bool, isLast: Bool,
                     trend: EmploymentSalaryTrend, nextTrend: EmploymentSalaryTrend?) -> some View {
        EmploymentTimelineRow(job: job, stages: stages, now: clock.now,
                              isFirst: isFirst, isLast: isLast, trend: trend, nextTrend: nextTrend,
                              onSelect: { selectedEmployment = job.id })
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

}

private struct ContributionAnalysisOverview: View {
    let jobs: [Employment]
    let kind: ContributionKind
    @Environment(CareerClock.self) private var clock
    @Query private var records: [ContributionStage]
    private var configuredTotal: Int64? {
        let values = CareerRules.employments(jobs).compactMap {
            ContributionEstimateRules.calculate(records, for: $0, kind: kind, through: clock.now)?.amountCents
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }
    var body: some View {
        List {
            if let configuredTotal {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("跨企业累计缴纳")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                        Text(ProfileRules.money(configuredTotal))
                            .font(.largeTitle.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                } footer: {
                    Text("按各企业已配置的基数和个人比例自动累计；缺少配置的月份不计入。")
                }.listRowBackground(AppTheme.cardBackground)
            }
            if kind == .pension {
                Section("跨企业分析") {
                    NavigationLink(value: ProfileRoute.socialInsuranceLimits) {
                        Label("基数范围", systemImage: "chart.bar.doc.horizontal")
                    }
                    .accessibilityIdentifier("pension.baseRange")
                    NavigationLink(value: ProfileRoute.pensionShortfall) {
                        Label("疑似少缴", systemImage: "exclamationmark.triangle")
                    }
                    .accessibilityIdentifier("pension.shortfall")
                }.listRowBackground(AppTheme.cardBackground)
            } else {
                Section("跨企业分析") {
                    NavigationLink(value: ProfileRoute.housingFundLimits) {
                        Label("基数范围", systemImage: "chart.bar.doc.horizontal")
                    }
                    .accessibilityIdentifier("housing.baseRange")
                    NavigationLink(value: ProfileRoute.housingShortfall) {
                        Label("疑似少缴", systemImage: "exclamationmark.triangle")
                    }
                    .accessibilityIdentifier("housing.shortfall")
                }.listRowBackground(AppTheme.cardBackground)
            }
            if jobs.isEmpty {
                ContentUnavailableView("尚无企业履历", systemImage: "building.2", description: Text("先录入任职经历，再到企业详情记录对应的\(kind.title)。"))
                NavigationLink("前往企业履历", value: CareerDestination.history)
            } else {
                Section {
                    Text("各企业的缴纳配置和累计金额，请到对应的企业详情查看与维护。")
                        .foregroundStyle(AppTheme.secondaryText)
                }.listRowBackground(AppTheme.cardBackground)
            }
        }
        .neutralPageBackground()
        .navigationTitle("\(kind.title)分析")
    }
}
