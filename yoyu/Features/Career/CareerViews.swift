import SwiftUI
import SwiftData

enum CareerDestination: Hashable { case history, review, employment(String), salary, work, pension, housing }

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
                                    Text("薪资变化与任职时长").font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "chart.xyaxis.line").foregroundStyle(DashboardStyle.accent)
                            }
                        }
                    }
                    if jobs.isEmpty { ContentUnavailableView("尚未录入企业履历", systemImage: "building.2", description: Text("添加当前任职，或补录过去的企业经历。")) }
                    let ordered = CareerRules.employments(jobs)
                    let current = ordered.filter { $0.isCurrent(on: clock.now) }
                    if current.count > 1 {
                        Text("有多段任职尚未结束，请完善离职月份后确定当前企业。")
                            .foregroundStyle(.orange)
                    }
                    if !ordered.isEmpty {
                        Section("任职时间线") {
                            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, job in
                                let trend = salaryTrend(at: index, in: ordered)
                                row(job, isFirst: index == 0, isLast: index == ordered.count - 1,
                                    trend: trend,
                                    nextTrend: index + 1 < ordered.count ? salaryTrend(at: index + 1, in: ordered) : nil)
                            }
                        }
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

struct CurrentEmploymentSection: View {
    @Query private var jobs: [Employment]
    @Environment(CareerClock.self) private var clock
    @Query private var stages: [SalaryStage]
    var body: some View {
        Section("当前企业") {
            if let job = CareerRules.current(jobs, on: clock.now) {
                LabeledContent("企业名称", value: job.displayName)
                LabeledContent("入职月份", value: CareerRules.employmentMonthLabel(job.start))
                LabeledContent("当前税前月薪", value: ProfileRules.money(CareerRules.salary(stages, for: job, on: clock.now)?.salaryCents))
                NavigationLink("查看任职详情", value: CareerDestination.employment(job.id))
            } else {
                Text(jobs.isEmpty ? "待完善" : CareerRules.employments(jobs).filter { $0.isCurrent(on: clock.now) }.count > 1 ? "多段任职未结束，请完善履历" : "暂无当前任职").foregroundStyle(.secondary)
                NavigationLink("管理企业履历", value: CareerDestination.history)
            }
        }
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
                            .foregroundStyle(.secondary)
                        Text(ProfileRules.money(configuredTotal))
                            .font(.largeTitle.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                } footer: {
                    Text("按各企业已配置的基数和个人比例自动累计；缺少配置的月份不计入。")
                }
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
                }
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
                }
            }
            if jobs.isEmpty {
                ContentUnavailableView("尚无企业履历", systemImage: "building.2", description: Text("先录入任职经历，再到企业详情记录对应的\(kind.title)。"))
                NavigationLink("前往企业履历", value: CareerDestination.history)
            } else {
                Section {
                    Text("各企业的缴纳配置和累计金额，请到对应的企业详情查看与维护。")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .neutralPageBackground()
        .navigationTitle("\(kind.title)分析")
    }
}

struct ContributionOverview: View {
    let job: Employment
    let kind: ContributionKind
    @Environment(CareerClock.self) private var clock
    @Query private var records: [ContributionStage]
    @Query private var salaries: [SalaryStage]
    @Query private var bonuses: [BonusPayment]
    @Query private var limits: [SocialInsuranceLimit]
    @Query private var housingLimits: [HousingFundLimit]
    @State private var adding = false
    @State private var editing: ContributionStage?

    private var ordered: [ContributionStage] { CareerRules.contributions(records, for: job, kind: kind) }
    private var current: ContributionStage? { CareerRules.contribution(records, for: job, kind: kind, on: clock.now) }
    private var pensionShortfall: PensionShortfallCompany? {
        guard kind == .pension else { return nil }
        return PensionShortfallRules.calculate(
            jobs: [job], salaries: salaries, bonuses: bonuses, contributions: records,
            limits: limits, through: clock.now
        ).first
    }
    private var housingShortfall: HousingShortfallCompany? {
        guard kind == .housing else { return nil }
        return HousingShortfallRules.calculate(
            jobs: [job], salaries: salaries, contributions: records,
            limits: housingLimits, through: clock.now
        ).first
    }
    private var estimate: ContributionEstimate? {
        ContributionEstimateRules.calculate(records, for: job, kind: kind, through: clock.now)
    }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    Text("累计缴纳").font(.subheadline).foregroundStyle(.secondary)
                    Text(estimate.map { ProfileRules.money($0.amountCents) } ?? "待补全配置")
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    Text("\(job.displayName) · 可计算 \(estimate?.coveredMonths ?? 0) 个月")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                if let shortfall = pensionShortfall {
                    NavigationLink {
                        PensionShortfallCompanyView(company: shortfall)
                    } label: {
                        LabeledContent("疑似少缴", value: shortfall.comparableCount == 0 ? "待补资料" : ProfileRules.money(shortfall.personalShortfallCents))
                    }
                }
                if let shortfall = housingShortfall {
                    NavigationLink {
                        HousingShortfallCompanyView(company: shortfall)
                    } label: {
                        LabeledContent("疑似少缴", value: shortfall.comparableCount == 0 ? "待补资料" : ProfileRules.money(shortfall.personalShortfallCents))
                    }
                }
                if kind == .pension {
                    NavigationLink {
                        PensionMonthlyPaymentsView(job: job)
                    } label: {
                        LabeledContent("逐月缴纳", value: "查看全部")
                    }
                    .accessibilityIdentifier("pension.monthlyPayments")
                } else {
                    NavigationLink {
                        HousingMonthlyPaymentsView(job: job)
                    } label: {
                        LabeledContent("逐月缴纳", value: "查看全部")
                    }
                    .accessibilityIdentifier("housing.monthlyPayments")
                }
            } footer: {
                Text(kind == .pension
                     ? "累计缴纳按配置推算；疑似少缴按工资、官方基数范围与配置基数对照，计算至上月。"
                     : "累计缴纳按配置推算；疑似少缴按工资、官方基数范围与配置基数对照，计算至上月。")
            }
            Section(job.isCurrent(on: clock.now) ? "当前缴纳配置" : "离职时缴纳配置") {
                if let current {
                    ContributionKindDetails(kind: kind, base: kind.base(current), rate: kind.rate(current))
                    LabeledContent("生效月份", value: CareerRules.monthLabel(current.effectiveMonth))
                } else {
                    Text("暂无缴纳配置")
                        .foregroundStyle(.secondary)
                }
            }
            if ordered.isEmpty {
                Section {
                    Text("还没有基数调整记录，点右上角添加。")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, record in
                        let previous = index + 1 < ordered.count ? ordered[index + 1] : nil
                        ContributionTimelineRow(
                            date: CareerRules.monthLabel(record.effectiveMonth),
                            amount: ProfileRules.money(kind.base(record)),
                            trend: EmploymentSalaryTrend(current: kind.base(record), previous: previous.flatMap(kind.base)),
                            isFirst: index == 0, isLast: index == ordered.count - 1,
                            rate: kind.rate(record).map { "\(ProfileRules.input($0))%" } ?? "待填写"
                        ) { editing = record }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("缴纳基数时间轴")
                } footer: {
                    Text("每条从生效月份起沿用，直到下一次调整；点选阶段可修改或删除。")
                }
            }
        }
        .neutralPageBackground()
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .navigationTitle(kind.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("新增\(kind.title)记录", systemImage: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $adding) { ContributionEditor(job: job, record: nil, previous: current, kind: kind) }
        .sheet(item: $editing) { ContributionEditor(job: job, record: $0, previous: nil, kind: kind) }
    }
}

private struct ContributionTimelineRow: View {
    let date: String
    let amount: String
    let trend: EmploymentSalaryTrend
    let isFirst: Bool
    let isLast: Bool
    let rate: String
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(trend.label)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(trend.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 44, height: 44, alignment: .trailing)
                .padding(.trailing, 8)

            VStack(spacing: 0) {
                Rectangle().fill(isFirst ? Color.clear : trend.color.opacity(0.5))
                    .frame(width: 1, height: 17)
                Circle().fill(trend.color).frame(width: 10, height: 10)
                Rectangle().fill(isLast ? Color.clear : trend.color.opacity(0.5))
                    .frame(width: 1).frame(maxHeight: .infinity)
            }
            .frame(width: 20)

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(date)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(amount)
                            .monospacedDigit()
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(height: 44)
                    Text("个人比例 \(rate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("查看、修改或删除这条记录")
        }
        .frame(minHeight: 74)
    }
}

private struct ContributionKindDetails: View {
    let kind: ContributionKind
    let base: Int64?
    let rate: Int64?
    var body: some View {
        LabeledContent("缴纳基数", value: ProfileRules.money(base))
        LabeledContent("个人比例", value: rate.map { "\(ProfileRules.input($0))%" } ?? "待填写")
    }
}
