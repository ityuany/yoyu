import SwiftUI
import SwiftData

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
                    Text("累计缴纳").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                    Text(estimate.map { ProfileRules.money($0.amountCents) } ?? "待补全配置")
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    Text("\(job.displayName) · 可计算 \(estimate?.coveredMonths ?? 0) 个月")
                        .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
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
            }.listRowBackground(AppTheme.cardBackground)
            Section(job.isCurrent(on: clock.now) ? "当前缴纳配置" : "离职时缴纳配置") {
                if let current {
                    ContributionKindDetails(kind: kind, base: kind.base(current), rate: kind.rate(current))
                    LabeledContent("生效月份", value: CareerRules.monthLabel(current.effectiveMonth))
                } else {
                    Text("暂无缴纳配置")
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }.listRowBackground(AppTheme.cardBackground)
            if ordered.isEmpty {
                Section {
                    Text("还没有基数调整记录，点右上角添加。")
                        .foregroundStyle(AppTheme.secondaryText)
                }.listRowBackground(AppTheme.cardBackground)
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
                }.listRowBackground(AppTheme.cardBackground)
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
                        .foregroundStyle(AppTheme.secondaryText)
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
