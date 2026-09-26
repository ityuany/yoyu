import SwiftUI
import SwiftData

enum CareerDestination: Hashable { case history, review, employment(String), salary, work, pension, housing, pensionEmployment(String), housingEmployment(String) }

struct CareerView: View {
    let destination: CareerDestination
    @Query private var jobs: [Employment]
    @Environment(CareerClock.self) private var clock
    @Query private var stages: [SalaryStage]
    @State private var adding = false
    @State private var selectedEmployment: String?

    private var job: Employment? {
        switch destination {
        case .employment(let id), .pensionEmployment(let id), .housingEmployment(let id):
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
                ContributionEmploymentList(jobs: jobs, now: clock.now, kind: destination == .pension ? .pension : .housing)
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
                case .pensionEmployment: ContributionOverview(job: job, kind: .pension)
                case .housingEmployment: ContributionOverview(job: job, kind: .housing)
                default: EmploymentDetail(job: job, mode: destination)
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

private struct EmploymentDetail: View {
    let job: Employment
    let mode: CareerDestination
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CareerClock.self) private var clock
    @Query private var stages: [SalaryStage]
    @Query private var holdings: [StockHolding]
    @Query private var contributions: [ContributionStage]
    @State private var editingJob = false
    @State private var addingSalary = false
    @State private var editingStage: SalaryStage?
    @State private var editingWork = false
    @State private var confirmingDeletion = false
    @State private var deletionError: String?
    private var salary: SalaryStage? { CareerRules.salary(stages, for: job, on: clock.now) }
    private var isWork: Bool { mode == .work }
    var body: some View {
        List {
            if !isWork {
                Section("任职信息") {
                    LabeledContent("企业名称", value: job.displayName)
                    LabeledContent("每月发薪日", value: "每月 \(job.salaryPaymentDay) 号")
                        .accessibilityIdentifier("employment.payday.summary")
                    LabeledContent("入职月份", value: CareerRules.employmentMonthLabel(job.start))
                    LabeledContent("离职月份", value: job.end.map { CareerRules.employmentMonthLabel($0) } ?? "目前在职")
                }
                if mode == .employment(job.id) {
                    CompanyStockSummary(job: job)
                }
                Section(job.isCurrent(on: clock.now) ? "当前待遇" : "离职时待遇") {
                    if let salary {
                        SalaryDetails(stage: salary)
                    } else { Text("薪资待遇待完善").foregroundStyle(.secondary) }
                }
                Section("社保与公积金") {
                    NavigationLink("养老保险", value: CareerDestination.pensionEmployment(job.id))
                    NavigationLink("住房公积金", value: CareerDestination.housingEmployment(job.id))
                }
                let orderedStages = CareerRules.stages(stages, for: job)
                ForEach(Array(orderedStages.enumerated()), id: \.element.id) { index, stage in
                    Section {
                        Button { editingStage = stage } label: {
                            SalaryStageCard(stage: stage, now: clock.now)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("编辑此阶段的薪资待遇")
                        .listRowInsets(EdgeInsets())
                    } header: {
                        if index == 0 { Text("薪资阶段") }
                    }
                }
                Section {
                    Button(job.isCurrent(on: clock.now) ? "记录调薪／补录阶段" : "补录薪资阶段", systemImage: "plus") { addingSalary = true }
                }
            }
            if mode != .salary {
                Section("工作安排") {
                    let week = Workweek(mask: job.workweekMask)
                    let days = Weekday.displayOrder.filter { week.contains($0) }.map(\.name)
                    LabeledContent("工作日", value: days.isEmpty ? "每周休息" : days.joined(separator: "、"))
                    LabeledContent("上班时间", value: ProfileRules.timeLabel(job.startMinutes))
                    LabeledContent("下班时间", value: "\(job.endMinutes < job.startMinutes ? "次日 " : "")\(ProfileRules.timeLabel(job.endMinutes))")
                    LabeledContent("遵循法定节假日及调休", value: job.followsHolidays ? "已开启" : "已关闭")
                    if let summary = CareerRules.workSummary(stages, for: job, on: clock.now) {
                        LabeledContent("累计应工作天数", value: "\(summary.days.formatted()) 天")
                        LabeledContent("平均日薪（税前估算）", value: summary.averageDailyCents.map { ProfileRules.money($0) } ?? (summary.days == 0 ? "暂无应工作日" : "薪资资料待补全"))
                        Text("按任职期间累计税前工资 ÷ 同期应工作天数计算，包含入离职当天，当前任职统计至今天；暂不含年终奖。")
                            .font(.caption).foregroundStyle(.secondary)
                        if summary.missingHolidayYears {
                            Text("部分年份节假日资料未收录，对应天数按每周工作日估算。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("编辑工作安排") { editingWork = true }
                }
            }
            if mode == .employment(job.id) {
                Section {
                    Button("删除任职记录", role: .destructive) { confirmingDeletion = true }
                }
            }
        }.neutralPageBackground()
        .navigationTitle(isWork ? "工作安排" : mode == .salary ? "薪资待遇" : job.displayName)
        .toolbar {
            if !isWork { ToolbarItem(placement: .primaryAction) { Button("编辑任职") { editingJob = true } } }
        }
        .sheet(isPresented: $editingJob) { EmploymentEditor(job: job) }
        .sheet(isPresented: $addingSalary) { SalaryEditor(job: job, stage: nil, previous: salary) }
        .sheet(item: $editingStage) { SalaryEditor(job: job, stage: $0, previous: nil) }
        .sheet(isPresented: $editingWork) { EmploymentWorkEditor(job: job) }
        .confirmationDialog("删除「\(job.displayName)」的任职记录？", isPresented: $confirmingDeletion, titleVisibility: .visible) {
            Button("删除任职及关联数据", role: .destructive) { deleteEmployment() }
            Button("取消", role: .cancel) { }
        } message: {
            Text(deletionMessage)
        }
        .saveErrorAlert($deletionError)
    }

    private var deletionMessage: String {
        var items = ["这段任职记录和工作安排"]
        let salaryCount = CareerRules.stages(stages, for: job).count
        if salaryCount > 0 { items.append("\(salaryCount) 条薪资记录") }
        let contributionCount = CareerRules.contributions(contributions, for: job).count
        if contributionCount > 0 { items.append("\(contributionCount) 条缴纳记录") }
        if job.severanceData != nil { items.append("补偿设置") }
        let stocks = StockRules.holdings(holdings.filter { $0.employmentID == job.id })
        if !stocks.isEmpty {
            let grants = stocks.compactMap(\.grants)
            let count = grants.count == stocks.count
                ? "（含 \(grants.reduce(0) { $0 + $1.count }) 笔授予）" : ""
            items.append("\(stocks.count) 份公司股票记录\(count)，包括持股、授予和归属计划")
        }
        return "将永久删除：\n" + items.map { "· " + $0 }.joined(separator: "\n")
            + "\n\n今日收入和财富统计会重新计算，此操作无法撤销。\n\n如果只是离职，请取消并填写离职月份。"
    }

    private func deleteEmployment() {
        do {
            try EmploymentDeletion.delete(id: job.id, context: context)
            dismiss()
        } catch {
            deletionError = "删除失败，请重试。\(error.localizedDescription)"
        }
    }
}

private struct SalaryDetails: View {
    let stage: SalaryStage
    var body: some View {
        LabeledContent("税前月薪", value: ProfileRules.money(stage.salaryCents))
        LabeledContent("年终奖", value: ProfileRules.money(stage.bonusCents))
        if stage.bonusCents != nil { LabeledContent("奖金发放月份", value: "\(stage.bonusMonth) 月") }
        if stage.effectiveDate == nil { Text("沿用已录入待遇，生效月份待补充。").font(.caption).foregroundStyle(.secondary) }
    }
}

private struct ContributionEmploymentList: View {
    let jobs: [Employment]
    let now: Date
    let kind: ContributionKind
    @Query private var records: [ContributionStage]
    @Query private var insuranceMonths: [SocialInsuranceMonth]

    private var current: [Employment] { CareerRules.employments(jobs).filter { $0.isCurrent(on: now) } }
    private var history: [Employment] { CareerRules.employments(jobs).filter { !$0.isCurrent(on: now) } }
    private var documentedMonths: [SocialInsuranceMonth] {
        Dictionary(grouping: insuranceMonths, by: \.id).values
            .compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
    }
    private var paidPensionMonths: [SocialInsuranceMonth] {
        documentedMonths.filter { $0.pensionPersonalCents != nil }
    }
    var body: some View {
        List {
            if kind == .pension {
                Section {
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
                Section {
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
            if kind == .pension && !paidPensionMonths.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("个人累计实缴")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(ProfileRules.money(paidPensionMonths.reduce(Int64.zero) { $0 + ($1.pensionPersonalCents ?? 0) }))
                            .font(.largeTitle.weight(.semibold))
                            .monospacedDigit()
                        Text("参保证明中有金额的 \(paidPensionMonths.count) 个月")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                } footer: {
                    Text("这是已记录的个人养老保险缴费合计，不是养老账户当前余额；未记录的月份不计入。")
                }
            }
            if jobs.isEmpty {
                ContentUnavailableView("尚无企业履历", systemImage: "building.2", description: Text("先录入任职经历，再记录对应企业的\(kind.title)。"))
                NavigationLink("前往企业履历", value: CareerDestination.history)
            }
            if !current.isEmpty {
                Section("当前任职") { ForEach(current) { job in row(job) } }
            }
            if !history.isEmpty {
                Section("历史任职") { ForEach(history) { job in row(job) } }
            }
        }
        .neutralPageBackground()
        .navigationTitle(kind.title)
    }
    private func row(_ job: Employment) -> some View {
        let configurationCount = CareerRules.contributions(records, for: job, kind: kind).count
        let proofCount = kind == .pension ? insuranceMonths.filter { $0.employmentID == job.id }.count : 0
        let countLabel = proofCount == 0 ? "\(configurationCount) 条基数记录" : "\(proofCount) 个月实缴\(configurationCount == 0 ? "" : " · \(configurationCount) 条基数记录")"
        return NavigationLink(value: kind == .pension ? CareerDestination.pensionEmployment(job.id) : .housingEmployment(job.id)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.displayName)
                Text("\(CareerRules.employmentMonthLabel(job.start)) 至 \(job.end.map { CareerRules.employmentMonthLabel($0) } ?? "目前在职") · \(countLabel)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ContributionOverview: View {
    let job: Employment
    let kind: ContributionKind
    @Environment(CareerClock.self) private var clock
    @Query private var records: [ContributionStage]
    @Query private var insuranceMonths: [SocialInsuranceMonth]
    @State private var adding = false
    @State private var editing: ContributionStage?

    private var current: ContributionStage? { CareerRules.contribution(records, for: job, kind: kind, on: clock.now) }
    private var documentedMonths: [SocialInsuranceMonth] {
        guard kind == .pension else { return [] }
        return Dictionary(grouping: insuranceMonths.filter { $0.employmentID == job.id }, by: \.id).values
            .compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted { $0.month > $1.month }
    }
    private var recordActionTitle: String {
        CareerRules.contributions(records, for: job, kind: kind).isEmpty
            ? "新增\(kind.title)记录" : "记录\(kind.title)调整"
    }
    var body: some View {
        List {
            Section("任职企业") { LabeledContent("企业名称", value: job.displayName) }
            Section(job.isCurrent(on: clock.now) ? "最近记录的缴纳配置" : "离职时缴纳") {
                if let current {
                    ContributionKindDetails(kind: kind, base: kind.base(current), rate: kind.rate(current))
                    LabeledContent("生效月份", value: CareerRules.monthLabel(current.effectiveMonth))
                    if kind == .pension, let through = current.pensionVerifiedThroughMonth {
                        LabeledContent("已核实沿用至", value: CareerRules.monthLabel(through))
                    }
                    Button("修改这条记录", systemImage: "pencil") { editing = current }
                } else {
                    Text(documentedMonths.isEmpty ? "暂无缴纳记录" : "未单独配置缴纳基数；下方为参保证明中的逐月实缴记录。")
                        .foregroundStyle(.secondary)
                }
            }
            let ordered = CareerRules.contributions(records, for: job, kind: kind)
            Section {
                Button(recordActionTitle, systemImage: "plus") { adding = true }
                ForEach(ordered) { record in
                    Button { editing = record } label: {
                        HStack {
                            ContributionKindStageRow(record: record, kind: kind)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("修改这条\(kind.title)记录")
                }
            } header: {
                Text("缴纳基数记录")
            } footer: {
                Text("每条从生效月份起沿用，直到下一次调整；无需逐月重复录入基数。")
            }
            if !documentedMonths.isEmpty {
                Section {
                    let total = documentedMonths.compactMap(\.pensionPersonalCents).reduce(Int64.zero, +)
                    LabeledContent("已记录个人养老缴费合计", value: ProfileRules.money(total))
                    ForEach(documentedMonths) { month in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(CareerRules.monthLabel(month.month)).fontWeight(.medium)
                            Text("缴费基数 \(ProfileRules.money(CareerRules.pensionBase(records, for: job, on: month.month) ?? month.pensionBaseCents)) · 个人实缴 \(ProfileRules.money(month.pensionPersonalCents))")
                                .foregroundStyle(.secondary)
                            Text(month.payerName + (month.remark.isEmpty ? "" : " · \(month.remark)"))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                } header: {
                    Text("参保证明 · \(documentedMonths.count) 个月")
                } footer: {
                    Text("仅统计证明列出的月份和个人养老缴费，不推算其他月份，也不代表养老账户余额。")
                }
            }
        }
        .neutralPageBackground()
        .navigationTitle(kind.title)
        .sheet(isPresented: $adding) { ContributionEditor(job: job, record: nil, previous: current, kind: kind) }
        .sheet(item: $editing) { ContributionEditor(job: job, record: $0, previous: nil, kind: kind) }
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

private struct ContributionKindStageRow: View {
    let record: ContributionStage
    let kind: ContributionKind
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(CareerRules.monthLabel(record.effectiveMonth) + "起").fontWeight(.medium)
            Text("基数 \(ProfileRules.money(kind.base(record))) · 个人比例 \(kind.rate(record).map { "\(ProfileRules.input($0))%" } ?? "待填写")")
                .foregroundStyle(.secondary)
            if kind == .pension, let through = record.pensionVerifiedThroughMonth {
                Text("已核实沿用至 \(CareerRules.monthLabel(through))")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
