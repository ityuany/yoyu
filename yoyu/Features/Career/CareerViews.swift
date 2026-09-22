import SwiftUI
import SwiftData

enum CareerDestination: Hashable { case history, review, employment(String), salary, work }

struct CareerView: View {
    let destination: CareerDestination
    @Query private var jobs: [Employment]
    @Environment(CareerClock.self) private var clock
    @Query private var stages: [SalaryStage]
    @State private var adding = false
    @State private var selectedEmployment: String?

    private var job: Employment? {
        if case .employment(let id) = destination { return CareerRules.employments(jobs).first { $0.id == id } }
        return CareerRules.current(jobs, on: clock.now)
    }
    var body: some View {
        Group {
            if destination == .review {
                CareerReviewView()
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
                    let current = CareerRules.employments(jobs).filter { $0.isCurrent(on: clock.now) }
                    let history = CareerRules.employments(jobs).filter { !$0.isCurrent(on: clock.now) }
                    if current.isEmpty {
                        Section("当前任职") { Text("暂无当前任职").foregroundStyle(.secondary) }
                    }
                    if current.count > 1 {
                        Text("有多段任职尚未结束，请完善离职日期后确定当前企业。")
                            .foregroundStyle(.orange)
                    }
                    ForEach(Array(current.enumerated()), id: \.element.id) { index, job in
                        Section { row(job) } header: {
                            if index == 0 { Text("当前任职") }
                        }
                    }
                    ForEach(Array(history.enumerated()), id: \.element.id) { index, job in
                        Section { row(job) } header: {
                            if index == 0 { Text("历史任职") }
                        }
                    }
                    if !jobs.isEmpty {
                        Section {} footer: {
                            Text("累计收入按各薪资阶段的税前月薪估算，按每月自然日折算，含入离职当天，暂不含年终奖。资料不完整时显示待补全。")
                        }
                    }
                }.neutralPageBackground()
                .listStyle(.insetGrouped)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .listSectionSpacing(.custom(12))
                .navigationTitle("企业履历")
                .toolbar { ToolbarItem(placement: .primaryAction) { Button("添加", systemImage: "plus") { adding = true } } }
            } else if let job {
                EmploymentDetail(job: job, mode: destination)
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
    private func row(_ job: Employment) -> some View {
        Button { selectedEmployment = job.id } label: {
            EmploymentOverviewCard(job: job, stages: stages, now: clock.now)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
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
                LabeledContent("入职日期", value: CareerRules.dateLabel(job.start))
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
                    LabeledContent("入职日期", value: CareerRules.dateLabel(job.start))
                    LabeledContent("离职日期", value: job.end.map { CareerRules.dateLabel($0) } ?? "目前在职")
                }
                if mode == .employment(job.id) {
                    CompanyStockSummary(job: job)
                }
                Section(job.isCurrent(on: clock.now) ? "当前待遇" : "离职时待遇") {
                    if let salary {
                        SalaryDetails(stage: salary)
                    } else { Text("薪资待遇待完善").foregroundStyle(.secondary) }
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
                    } footer: {
                        if index == orderedStages.count - 1 {
                            Text("养老、公积金个人月缴纳金额按各阶段税前月薪与比例估算。")
                        }
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
        if job.severanceData != nil { items.append("补偿设置") }
        let stocks = StockRules.holdings(holdings.filter { $0.employmentID == job.id })
        if !stocks.isEmpty {
            let grants = stocks.compactMap(\.grants)
            let count = grants.count == stocks.count
                ? "（含 \(grants.reduce(0) { $0 + $1.count }) 笔授予）" : ""
            items.append("\(stocks.count) 份公司股票记录\(count)，包括持股、授予和归属计划")
        }
        return "将永久删除：\n" + items.map { "· " + $0 }.joined(separator: "\n")
            + "\n\n今日收入和财富统计会重新计算，此操作无法撤销。\n\n如果只是离职，请取消并填写离职日期。"
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
        contribution("养老金", rate: stage.pensionBasisPoints)
        contribution("公积金", rate: stage.housingBasisPoints)
        LabeledContent("年终奖", value: ProfileRules.money(stage.bonusCents))
        if stage.bonusCents != nil { LabeledContent("奖金发放月份", value: "\(stage.bonusMonth) 月") }
        if stage.effectiveDate == nil { Text("沿用已录入待遇，生效日期待补充。").font(.caption).foregroundStyle(.secondary) }
    }
    private func contribution(_ title: String, rate: Int64?) -> some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 4) {
                Text(rate.map { "\(ProfileRules.input($0))%" } ?? "待填写")
                if let amount = ProfileRules.monthlyContribution(salaryCents: stage.salaryCents, rateBasisPoints: rate) {
                    Text("\(ProfileRules.money(amount))/月（估算）").font(.caption).foregroundStyle(.secondary)
                }
            }
        } label: { Text(title) }
    }
}
