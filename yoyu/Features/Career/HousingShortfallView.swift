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
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(ProfileRules.money(companies.reduce(0) { $0 + $1.personalShortfallCents }))
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    Text("有差额 \(companies.reduce(0) { $0 + $1.positiveCount }) 个月 · 已比较 \(companies.reduce(0) { $0 + $1.comparableCount }) 个月 · 待补 \(companies.reduce(0) { $0 + $1.missingCount }) 个月")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if companies.isEmpty {
                ContentUnavailableView("暂无可计算的任职", systemImage: "building.2", description: Text("请先完善企业履历和住房公积金记录。"))
            }
            Section {
                if visible.isEmpty {
                    Text("补全可比较的月份后显示年度变化。").foregroundStyle(.secondary)
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
            }
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
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("计算口径") {
                Text("逐月取该企业当月生效的工资，低于已配置下限按下限、高于上限按上限，其余按工资计算参考基数；再与该月生效的已录公积金缴费基数比较。正向基数差按录入的个人缴存比例估算至上月。没有逐月实缴凭证，不能据此确认欠缴金额。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
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
                .background(Color(uiColor: .systemBackground))
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
                    .foregroundStyle(String(item.year) == selectedYear ? .orange : DashboardStyle.accent)
                    .accessibilityLabel("\(item.year) 年，\(ProfileRules.money(item.cents))")
            }
            .chartXSelection(value: $selectedYear)
            .accessibilityLabel("年度疑似少缴趋势")
        }
    }
}

private struct HousingShortfallCompanyView: View {
    let company: HousingShortfallCompany
    var body: some View {
        List {
            Section {
                LabeledContent("疑似少缴 · 个人部分", value: ProfileRules.money(company.personalShortfallCents))
                LabeledContent("已比较", value: "\(company.comparableCount) 个月")
                LabeledContent("待补资料", value: "\(company.missingCount) 个月")
            }
            Section("逐月对照") {
                ForEach(company.months) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(CareerRules.monthLabel(item.month)).font(.headline)
                            Spacer()
                            Text(item.personalShortfallCents.map { ProfileRules.money($0) } ?? "待补资料")
                                .foregroundStyle((item.personalShortfallCents ?? 0) > 0 ? .orange : .secondary)
                        }
                        if let reason = item.missing {
                            Text(reason.rawValue).foregroundStyle(.secondary)
                        } else {
                            Text("当月工资 \(ProfileRules.money(item.wageCents))")
                                .font(.subheadline)
                            Text("参考基数 \(ProfileRules.money(item.expectedBaseCents)) · 已录基数 \(ProfileRules.money(item.recordedBaseCents))")
                            Text("个人比例 \(String(format: "%.2f", Double(item.rateBasisPoints ?? 0) / 100))% · \(item.limitEvidence?.title ?? "")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .neutralPageBackground()
        .navigationTitle(company.job.displayName)
    }
}
