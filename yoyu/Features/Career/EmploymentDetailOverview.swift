import SwiftUI
import SwiftData

struct EmploymentDetailOverview: View {
    let job: Employment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CareerClock.self) private var clock
    @Environment(AppNavigation.self) private var navigation
    @Query private var salaries: [SalaryStage]
    @Query private var bonuses: [BonusPayment]
    @Query private var holdings: [StockHolding]
    @Query private var contributions: [ContributionStage]
    @State private var editingJob = false
    @State private var confirmingDeletion = false
    @State private var deletionError: String?

    private var currentSalary: SalaryStage? { CareerRules.salary(salaries, for: job, on: clock.now) }
    private var latestBonus: BonusPayment? { BonusRules.confirmed(bonuses, for: job).first }
    private var hasBonusRecords: Bool { !BonusRules.payments(bonuses, for: job).isEmpty }
    private var holding: StockHolding? {
        StockRules.holdings(holdings).first { $0.employmentID == job.id }
    }
    private var pensionEstimate: ContributionEstimate? {
        ContributionEstimateRules.calculate(contributions, for: job, kind: .pension, through: clock.now)
    }
    private var housingEstimate: ContributionEstimate? {
        ContributionEstimateRules.calculate(contributions, for: job, kind: .housing, through: clock.now)
    }
    private var workLabel: String {
        let days = Weekday.displayOrder.filter { Workweek(mask: job.workweekMask).contains($0) }
        let schedule = days.isEmpty ? "每周休息" : days.count == 5 && days.map(\.name) == ["周一", "周二", "周三", "周四", "周五"] ? "周一至周五" : days.map(\.name).joined(separator: "、")
        return "\(schedule) · \(ProfileRules.timeLabel(job.startMinutes))–\(ProfileRules.timeLabel(job.endMinutes))"
    }
    private var tenure: String {
        guard let start = job.start else { return "入职月份待补全" }
        let end = min(job.end ?? clock.now, clock.now)
        let parts = ProfileRules.calendar.dateComponents([.year, .month], from: start, to: end)
        let duration = "\(parts.year ?? 0) 年 \(parts.month ?? 0) 个月"
        if let departure = job.end {
            return "\(CareerRules.monthLabel(start)) 至 \(CareerRules.monthLabel(departure)) · 任职 \(duration)"
        }
        return "\(CareerRules.monthLabel(start)) 入职 · 已任职 \(duration)"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(job.displayName).font(.title2.weight(.bold))
                    Text(tenure).font(.subheadline).foregroundStyle(.secondary)
                    Divider()
                    HStack(alignment: .top, spacing: 16) {
                        total("累计月薪", value: CareerRules.estimatedSalaryCents(salaries, for: job, on: clock.now))
                        total("累计年终", value: BonusRules.total(bonuses, for: job), empty: hasBonusRecords ? "待确认" : "暂无记录")
                    }
                }
                .padding(.vertical, 6)
            }
            Section("待遇") {
                NavigationLink {
                    SalaryTimelineView(job: job)
                } label: {
                    LabeledContent(job.isCurrent(on: clock.now) ? "当前月薪" : "离职时月薪", value: ProfileRules.money(currentSalary?.salaryCents))
                }
                NavigationLink {
                    BonusTimelineView(job: job)
                } label: {
                    LabeledContent("最近年终奖", value: latestBonus.map { ProfileRules.money($0.amountCents) } ?? (hasBonusRecords ? "待确认" : "暂无记录"))
                }
            }
            Section {
                Button {
                    navigation.openStocks(holdingID: holding?.id)
                } label: {
                    HStack {
                        Text("公司股票").foregroundStyle(.primary)
                        Spacer()
                        Text(holding.flatMap { StockRules.balance($0, on: clock.now) }.map { "已归属 \(ProfileRules.input($0.vestedShares)) 股" } ?? "未关联")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                sourceHeader("股票激励", source: "数据来自财富")
            }
            Section {
                NavigationLink {
                    ContributionOverview(job: job, kind: .pension)
                } label: {
                    LabeledContent("累计养老", value: ProfileRules.money(pensionEstimate?.amountCents))
                }
                NavigationLink {
                    ContributionOverview(job: job, kind: .housing)
                } label: {
                    LabeledContent("累计公积金", value: ProfileRules.money(housingEstimate?.amountCents))
                }
            } header: {
                sourceHeader("社保与公积金", source: "数据来自缴纳记录")
            } footer: {
                Text("按各阶段的缴纳基数和个人比例自动累计；实际到账金额可能略有差异。")
            }
            Section("工时安排") {
                NavigationLink {
                    EmploymentWorkDetail(job: job)
                } label: {
                    LabeledContent("工作时间", value: workLabel)
                }
            }
            Section("任职信息") {
                LabeledContent("入职月份", value: job.start.map(CareerRules.monthLabel) ?? "待填写")
                LabeledContent("离职月份", value: job.end.map(CareerRules.monthLabel) ?? "在职")
                LabeledContent("发薪日", value: "每月 \(job.salaryPaymentDay) 号")
                    .accessibilityIdentifier("employment.payday.summary")
            }
            Section {
                Button("删除任职记录", role: .destructive) { confirmingDeletion = true }
            }
        }
        .neutralPageBackground()
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .listSectionSpacing(.custom(12))
        .navigationTitle(job.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("编辑任职") { editingJob = true } }
        }
        .sheet(isPresented: $editingJob) { EmploymentEditor(job: job) }
        .confirmationDialog("删除「\(job.displayName)」的任职记录？", isPresented: $confirmingDeletion, titleVisibility: .visible) {
            Button("删除任职及关联数据", role: .destructive) { deleteEmployment() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("这段任职及关联的薪资、年终奖、缴纳和股票记录将一并删除。此操作无法撤销。如果只是离职，请取消并填写离职月份。")
        }
        .saveErrorAlert($deletionError)
    }

    private func total(_ title: String, value: Int64?, empty: String = "待填写") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value.map { ProfileRules.money($0, compact: true) } ?? empty)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sourceHeader(_ title: String, source: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(source).font(.caption).textCase(nil)
        }
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

struct EmploymentWorkDetail: View {
    let job: Employment
    @Environment(CareerClock.self) private var clock
    @Query private var stages: [SalaryStage]
    @State private var editing = false

    var body: some View {
        List {
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
                Button("编辑工作安排") { editing = true }
            }
        }
        .neutralPageBackground()
        .navigationTitle("工作安排")
        .sheet(isPresented: $editing) { EmploymentWorkEditor(job: job) }
    }
}
