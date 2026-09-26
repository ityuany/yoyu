import SwiftUI
import SwiftData

struct SalaryTimelineView: View {
    let job: Employment
    @Environment(CareerClock.self) private var clock
    @Query private var stages: [SalaryStage]
    @State private var adding = false
    @State private var editing: SalaryStage?

    private var ordered: [SalaryStage] { CareerRules.stages(stages, for: job) }
    private var current: SalaryStage? { CareerRules.salary(stages, for: job, on: clock.now) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    Text(job.isCurrent(on: clock.now) ? "当前税前月薪" : "离职时税前月薪")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(ProfileRules.money(current?.salaryCents))
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    if let date = current?.effectiveDate {
                        Text("\(CareerRules.monthLabel(date)) 起生效")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            if ordered.isEmpty {
                ContentUnavailableView("尚无薪资阶段", systemImage: "calendar", description: Text("点右上角添加入职月薪或一次调薪。"))
            } else {
                Section("调薪时间轴") {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, stage in
                        let previous = index + 1 < ordered.count ? ordered[index + 1] : nil
                        CompensationTimelineRow(
                            date: stage.effectiveDate.map(CareerRules.monthLabel) ?? "月份待补充",
                            amount: ProfileRules.money(stage.salaryCents),
                            trend: EmploymentSalaryTrend(current: stage.salaryCents, previous: previous?.salaryCents),
                            isFirst: index == 0, isLast: index == ordered.count - 1,
                            note: stage.effectiveDate.map { $0 > clock.now ? "待生效" : "" } ?? "待补日期"
                        ) { editing = stage }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .neutralPageBackground()
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .navigationTitle("薪资变化")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("新增薪资阶段", systemImage: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $adding) { SalaryEditor(job: job, stage: nil, previous: current) }
        .sheet(item: $editing) { SalaryEditor(job: job, stage: $0, previous: nil) }
    }
}

struct BonusTimelineView: View {
    let job: Employment
    @Query private var bonuses: [BonusPayment]
    @State private var adding = false
    @State private var editing: BonusPayment?

    private var ordered: [BonusPayment] { BonusRules.payments(bonuses, for: job) }
    private var pendingCount: Int { ordered.filter { $0.year == nil }.count }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    Text("累计年终收入").font(.subheadline).foregroundStyle(.secondary)
                    Text(ordered.isEmpty ? "暂无记录" : ProfileRules.money(BonusRules.total(bonuses, for: job)))
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    Text(ordered.isEmpty ? "仅统计实际收到的税前年终奖" : pendingCount == 0 ? "已确认的税前实发金额" : "\(pendingCount) 笔旧记录待确认年份，暂未计入")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            if ordered.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "gift")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 56, height: 56)
                            .background(Color.secondary.opacity(0.1), in: Circle())
                            .accessibilityHidden(true)
                        Text("还没有年终奖记录")
                            .font(.headline)
                        Text("收到税前年终奖后，点右上角记录。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                } footer: {
                    Text("这家企业没有发放年终奖时，无需添加记录。")
                }
            } else {
                Section("年终奖时间轴") {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, payment in
                        let previous = index + 1 < ordered.count ? ordered[index + 1] : nil
                        CompensationTimelineRow(
                            date: payment.year.map { "\($0) 年 \(payment.month) 月" } ?? "发放年份待确认",
                            amount: ProfileRules.money(payment.amountCents),
                            trend: EmploymentSalaryTrend(current: payment.year == nil ? nil : payment.amountCents,
                                                         previous: previous?.year == nil ? nil : previous?.amountCents),
                            isFirst: index == 0, isLast: index == ordered.count - 1,
                            note: payment.year == nil ? "待补年份" : ""
                        ) { editing = payment }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .neutralPageBackground()
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .navigationTitle("年终奖记录")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("新增年终奖", systemImage: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $adding) { BonusPaymentEditor(job: job, payment: nil) }
        .sheet(item: $editing) { BonusPaymentEditor(job: job, payment: $0) }
    }
}

struct CompensationTimelineRow: View {
    let date: String
    let amount: String
    let trend: EmploymentSalaryTrend
    let isFirst: Bool
    let isLast: Bool
    let note: String
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(trend.label)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(trend.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 44, height: 56, alignment: .trailing)
                .padding(.trailing, 8)
            VStack(spacing: 0) {
                Rectangle().fill(isFirst ? Color.clear : trend.color.opacity(0.5))
                    .frame(width: 1, height: 23)
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
                    .frame(height: 56)
                    if !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 12)
                    } else {
                        Color.clear.frame(height: 16)
                    }
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("查看、修改或删除这条记录")
        }
        .frame(minHeight: 72)
    }
}
