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
                    Text(tenure).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                    Divider()
                    HStack(alignment: .top, spacing: 16) {
                        total("累计月薪", value: CareerRules.estimatedSalaryCents(salaries, for: job, on: clock.now))
                        total("累计年终", value: BonusRules.total(bonuses, for: job), empty: hasBonusRecords ? "待确认" : "暂无记录")
                    }
                }
                .padding(.vertical, 6)
            }.listRowBackground(AppTheme.cardBackground)
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
            }.listRowBackground(AppTheme.cardBackground)
            Section {
                Button {
                    navigation.openStocks(holdingID: holding?.id)
                } label: {
                    HStack {
                        Text("公司股票").foregroundStyle(AppTheme.primaryText)
                        Spacer()
                        Text(holding.flatMap { StockRules.balance($0, on: clock.now) }.map { "已归属 \(ProfileRules.input($0.vestedShares)) 股" } ?? "未关联")
                            .foregroundStyle(AppTheme.secondaryText)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                sourceHeader("股票激励", source: "数据来自财富")
            }.listRowBackground(AppTheme.cardBackground)
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
            }.listRowBackground(AppTheme.cardBackground)
            Section("工时安排") {
                NavigationLink {
                    EmploymentWorkDetail(job: job)
                } label: {
                    LabeledContent("工作时间", value: workLabel)
                }
            }.listRowBackground(AppTheme.cardBackground)
            Section("任职信息") {
                LabeledContent("入职月份", value: job.start.map(CareerRules.monthLabel) ?? "待填写")
                LabeledContent("离职月份", value: job.end.map(CareerRules.monthLabel) ?? "在职")
                LabeledContent("发薪日", value: "每月 \(job.salaryPaymentDay) 号")
                    .accessibilityIdentifier("employment.payday.summary")
            }.listRowBackground(AppTheme.cardBackground)
            Section {
                Button("删除任职记录", role: .destructive) { confirmingDeletion = true }
            }.listRowBackground(AppTheme.cardBackground)
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
            Text(title).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
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
