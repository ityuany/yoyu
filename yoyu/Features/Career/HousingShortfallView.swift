import SwiftUI
import SwiftData
import Charts

struct HousingShortfallView: View {
    @Query private var jobs: [Employment]
    @Query private var salaries: [SalaryStage]
    @Query private var contributions: [ContributionStage]
    @Query private var limits: [HousingFundLimit]
    @Environment(CareerClock.self) private var clock
    @State private var showsAllYears = true
    @State private var selectedYear: String?
    @State private var showsFullscreen = false

    private struct YearAmount: Identifiable {
        let year: Int
        let cents: Int64
        var id: Int { year }
    }

    var body: some View {
        let companies = HousingShortfallRules.calculate(
            jobs: jobs, salaries: salaries, contributions: contributions,
            limits: limits, through: clock.now
        )
        let grouped = Dictionary(grouping: companies.flatMap(\.months).compactMap { month -> (Int, Int64)? in
            guard let amount = month.personalShortfallCents else { return nil }
            return (ProfileRules.calendar.component(.year, from: month.month), amount)
        }, by: \.0)
        let years = grouped.map { YearAmount(year: $0.key, cents: $0.value.reduce(0) { $0 + $1.1 }) }
            .sorted { $0.year < $1.year }
        let visible = showsAllYears ? years : years.filter { $0.year >= (years.last?.year ?? 0) - 4 }
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("疑似少缴 · 个人部分")
                        .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                    Text(ProfileRules.money(companies.reduce(0) { $0 + $1.personalShortfallCents }))
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    Text("有差额 \(companies.reduce(0) { $0 + $1.positiveCount }) 个月 · 已比较 \(companies.reduce(0) { $0 + $1.comparableCount }) 个月 · 待补 \(companies.reduce(0) { $0 + $1.missingCount }) 个月")
                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                }
            }.listRowBackground(AppTheme.cardBackground)
            if companies.isEmpty {
                ContentUnavailableView("暂无可计算的任职", systemImage: "building.2", description: Text("请先完善企业履历和住房公积金记录。"))
            }
            Section {
                if visible.isEmpty {
                    Text("补全可比较的月份后显示年度变化。").foregroundStyle(AppTheme.secondaryText)
                } else {
                    Picker("时间范围", selection: $showsAllYears) {
                        Text("全部").tag(true)
                        Text("近 5 年").tag(false)
                    }
                    .pickerStyle(.segmented)
                    HousingYearChart(years: visible, selectedYear: $selectedYear)
                        .frame(height: 205)
                    if let selectedYear, let selected = visible.first(where: { String($0.year) == selectedYear }) {
                        Text("\(selected.year) 年 · \(ProfileRules.money(selected.cents))")
                            .font(.subheadline).monospacedDigit()
                    }
                }
            } header: {
                HStack {
                    Text("年度变化")
                    Spacer()
                    if !visible.isEmpty {
                        Button { showsFullscreen = true } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("全屏查看年度变化")
                    }
                }
            }.listRowBackground(AppTheme.cardBackground)
            Section("企业排行") {
                ForEach(companies.sorted { $0.personalShortfallCents > $1.personalShortfallCents }) { company in
                    NavigationLink {
                        HousingShortfallCompanyView(company: company)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(company.job.displayName).font(.headline)
                                Spacer()
                                Text(company.comparableCount == 0 ? "待补资料" : ProfileRules.money(company.personalShortfallCents))
                                    .monospacedDigit()
                            }
                            Text("有差额 \(company.positiveCount) / 已比较 \(company.comparableCount) 个月 · 待补 \(company.missingCount) 个月")
                                .font(.caption).foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
            }.listRowBackground(AppTheme.cardBackground)
            Section("计算口径") {
                Text("逐月取该企业当月生效的工资，低于已配置下限按下限、高于上限按上限，其余按工资计算参考基数；再与该月生效的公积金配置基数比较。正向基数差按配置的个人缴存比例估算至上月。此数只作参考，不是已核实欠缴额。")
                    .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            }.listRowBackground(AppTheme.cardBackground)
        }
        .neutralPageBackground()
        .navigationTitle("疑似少缴")
        .fullScreenCover(isPresented: $showsFullscreen) {
            GeometryReader { proxy in
                let rotated = proxy.size.height > proxy.size.width
                VStack(spacing: 12) {
                    HStack {
                        Text("年度变化").font(.headline)
                        Spacer()
                        Picker("时间范围", selection: $showsAllYears) {
                            Text("全部").tag(true)
                            Text("近 5 年").tag(false)
                        }
                        .pickerStyle(.segmented).frame(width: 190)
                        Button { showsFullscreen = false } label: {
                            Image(systemName: "xmark").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("关闭全屏图表")
                    }
                    HousingYearChart(years: visible, selectedYear: $selectedYear)
                    if let selectedYear, let selected = visible.first(where: { String($0.year) == selectedYear }) {
                        Text("\(selected.year) 年 · \(ProfileRules.money(selected.cents))").monospacedDigit()
                    }
                }
                .padding(24)
                .frame(width: rotated ? proxy.size.height : proxy.size.width,
                       height: rotated ? proxy.size.width : proxy.size.height)
                .background(AppTheme.pageBackground)
                .rotationEffect(.degrees(rotated ? 90 : 0))
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }

    private struct HousingYearChart: View {
        let years: [YearAmount]
        @Binding var selectedYear: String?
        var body: some View {
            Chart(years) { item in
                BarMark(x: .value("年份", String(item.year)), y: .value("金额（元）", Double(item.cents) / 100))
                    .foregroundStyle(String(item.year) == selectedYear ? AppTheme.warning : DashboardStyle.accent)
                    .accessibilityLabel("\(item.year) 年，\(ProfileRules.money(item.cents))")
            }
            .chartXSelection(value: $selectedYear)
            .accessibilityLabel("年度疑似少缴趋势")
        }
    }
}

struct HousingMonthlyPaymentsView: View {
    let job: Employment
    @Environment(CareerClock.self) private var clock
    @Query private var salaries: [SalaryStage]
    @Query private var contributions: [ContributionStage]
    @Query private var limits: [HousingFundLimit]

    private var completed: [HousingShortfallMonth] {
        HousingShortfallRules.calculate(
            jobs: [job], salaries: salaries, contributions: contributions,
            limits: limits, through: clock.now
        ).first?.months ?? []
    }

    private var currentMonth: (date: Date, amount: Int64?)? {
        let month = CareerRules.monthStart(clock.now)
        guard let start = job.start, CareerRules.monthStart(start) <= month,
              job.end == nil || job.end! >= month else { return nil }
        let stage = CareerRules.contribution(contributions, for: job, kind: .housing, on: month)
        return (month, ProfileRules.monthlyContribution(
            salaryCents: stage?.housingBaseCents, rateBasisPoints: stage?.housingBasisPoints
        ))
    }

    var body: some View {
        List {
            if let currentMonth {
                Section("本月") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(CareerRules.monthLabel(currentMonth.date))
                            Spacer()
                            Text(amountLabel(currentMonth.amount)).fontWeight(.semibold)
                        }
                        Text(currentMonth.amount == nil ? "待补缴纳基数或个人比例" : "本月进行中 · 按当前配置推算")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .monospacedDigit()
                }.listRowBackground(AppTheme.cardBackground)
            }
            if completed.isEmpty && currentMonth == nil {
                ContentUnavailableView("暂无逐月数据", systemImage: "calendar", description: Text("请先补全企业任职月份和住房公积金缴纳配置。"))
            } else {
                Section {
                    ForEach(completed) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(CareerRules.monthLabel(item.month))
                                Spacer()
                                Text(amountLabel(item.configuredPaymentCents)).fontWeight(.semibold)
                            }
                            HStack {
                                Text(item.comparison?.title ?? item.missing?.rawValue ?? "待补资料")
                                    .foregroundStyle(statusColor(item.comparison))
                                Spacer()
                                if let expected = item.expectedPaymentCents {
                                    Text("参考 \(ProfileRules.money(expected))")
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                            .font(.subheadline)
                            if let base = item.recordedBaseCents, let expected = item.expectedBaseCents {
                                Text("配置基数 \(ProfileRules.money(base)) · 参考基数 \(ProfileRules.money(expected))")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                        .monospacedDigit()
                        .padding(.vertical, 3)
                    }
                } header: {
                    Text("已结束月份")
                } footer: {
                    Text("每月金额按当月配置基数 × 个人比例推算；对比状态按配置基数与工资经官方上下限约束后的参考基数判断。")
                }.listRowBackground(AppTheme.cardBackground)
            }
        }
        .neutralPageBackground()
        .listStyle(.insetGrouped)
        .navigationTitle("逐月缴纳")
    }

    private func amountLabel(_ amount: Int64?) -> String {
        amount.map { ProfileRules.money($0) } ?? "待补配置"
    }

    private func statusColor(_ comparison: HousingShortfallMonth.Comparison?) -> Color {
        switch comparison {
        case .matches: AppTheme.success
        case .above: AppTheme.accent
        case .below: AppTheme.warning
        case nil: .secondary
        }
    }
}

struct HousingShortfallCompanyView: View {
    let company: HousingShortfallCompany
    var body: some View {
        List {
            Section {
                LabeledContent("疑似少缴 · 个人部分", value: ProfileRules.money(company.personalShortfallCents))
                LabeledContent("少缴月份", value: "\(company.positiveCount) 个月")
                LabeledContent("已比较", value: "\(company.comparableCount) 个月")
                LabeledContent("待补资料", value: "\(company.missingCount) 个月")
            }.listRowBackground(AppTheme.cardBackground)
            if company.shortfallMonths.isEmpty {
                ContentUnavailableView(
                    "暂无疑似少缴月份",
                    systemImage: "checkmark.circle",
                    description: Text(company.comparableCount == 0
                                      ? "暂无可比较的月份，请补全工资、基数范围和缴纳配置。"
                                      : "已比较的月份均未发现少缴。")
                )
            } else {
                Section("少缴月份") {
                    ForEach(company.shortfallMonths) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(CareerRules.monthLabel(item.month)).font(.headline)
                                Spacer()
                                Text(ProfileRules.money(item.personalShortfallCents))
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.warning)
                            }
                            Text("当月工资 \(ProfileRules.money(item.wageCents))")
                                .font(.subheadline)
                            Text("应缴基数 \(ProfileRules.money(item.expectedBaseCents)) · 配置基数 \(ProfileRules.money(item.recordedBaseCents))")
                            Text("个人比例 \(String(format: "%.2f", Double(item.rateBasisPoints ?? 0) / 100))% · \(item.limitEvidence?.symbol ?? "")\(item.limitEvidence?.title ?? "")")
                                .font(.caption).foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(.vertical, 3)
                    }
                }.listRowBackground(AppTheme.cardBackground)
            }
        }
        .neutralPageBackground()
        .navigationTitle(company.job.displayName)
    }
}
