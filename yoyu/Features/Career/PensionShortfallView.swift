import SwiftUI
import SwiftData
import Charts

private enum ShortfallRanking: String, CaseIterable, Identifiable {
    case total = "总额"
    case monthly = "月均"
    case rate = "差额率"

    var id: String { rawValue }

    func score(_ company: PensionShortfallCompany) -> Double? {
        guard company.comparableCount > 0 else { return nil }
        return switch self {
        case .total: Double(company.personalShortfallCents)
        case .monthly: company.averageMonthlyShortfallCents.map(Double.init)
        case .rate: company.shortfallRate
        }
    }

    func label(_ company: PensionShortfallCompany) -> String {
        guard score(company) != nil else { return "待补资料" }
        return switch self {
        case .total: ProfileRules.money(company.personalShortfallCents)
        case .monthly: ProfileRules.money(company.averageMonthlyShortfallCents)
        case .rate: String(format: "%.1f%%", (company.shortfallRate ?? 0) * 100)
        }
    }

    func sorted(_ companies: [PensionShortfallCompany]) -> [PensionShortfallCompany] {
        companies.sorted {
            let left = score($0) ?? -1
            let right = score($1) ?? -1
            if left != right { return left > right }
            return $0.job.displayName.localizedStandardCompare($1.job.displayName) == .orderedAscending
        }
    }
}

private struct ShortfallYear: Identifiable {
    let year: Int
    let amountCents: Int64
    var id: Int { year }
}

struct PensionShortfallView: View {
    @Query private var jobs: [Employment]
    @Query private var salaries: [SalaryStage]
    @Query private var contributions: [ContributionStage]
    @Query private var proofMonths: [SocialInsuranceMonth]
    @Query private var limits: [SocialInsuranceLimit]
    @Environment(CareerClock.self) private var clock
    @State private var ranking: ShortfallRanking = .total
    @State private var showsTrendFullscreen = false
    @State private var showsRankingFullscreen = false
    @State private var showsAllYears = true
    @State private var selectedYear: String?

    private func yearlyAmounts(for companies: [PensionShortfallCompany]) -> [ShortfallYear] {
        let values = companies.flatMap(\.months).compactMap { item -> (Int, Int64)? in
            guard let amount = item.personalShortfallCents else { return nil }
            return (ProfileRules.calendar.component(.year, from: item.month), amount)
        }
        return Dictionary(grouping: values, by: \.0).map { year, items in
            ShortfallYear(year: year, amountCents: items.reduce(0) { $0 + $1.1 })
        }.sorted { $0.year < $1.year }
    }

    var body: some View {
        let companies = PensionShortfallRules.calculate(
            jobs: jobs, salaries: salaries, contributions: contributions,
            proofMonths: proofMonths, limits: limits, through: clock.now
        )
        let yearlyAmounts = yearlyAmounts(for: companies)
        let visibleYears: [ShortfallYear] = if !showsAllYears, let latest = yearlyAmounts.last?.year {
            yearlyAmounts.filter { $0.year >= latest - 4 }
        } else {
            yearlyAmounts
        }
        let rankedCompanies = ranking.sorted(companies)
        let rankingMaximum = rankedCompanies.compactMap { ranking.score($0) }.max() ?? 0
        let positiveMonths = companies.reduce(0) { $0 + $1.positiveCount }
        let comparableMonths = companies.reduce(0) { $0 + $1.comparableCount }
        let missingMonths = companies.reduce(0) { $0 + $1.missingCount }

        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("疑似少缴 · 个人部分")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(ProfileRules.money(companies.reduce(Int64.zero) { $0 + $1.personalShortfallCents }))
                        .font(.largeTitle.weight(.semibold))
                        .monospacedDigit()
                    HStack(spacing: 8) {
                        summaryNumber("有差额", value: "\(positiveMonths) 个月")
                        summaryNumber("已比较", value: "\(comparableMonths) 个月")
                        summaryNumber("待补资料", value: "\(missingMonths) 个月")
                    }
                }
            }
            if companies.isEmpty {
                ContentUnavailableView("暂无可计算的任职", systemImage: "building.2", description: Text("请先完善企业履历和养老保险缴费记录。"))
            }
            Section {
                if yearlyAmounts.isEmpty {
                    Text("补全可比较的月份后显示年度变化。")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("时间范围", selection: $showsAllYears) {
                        Text("全部").tag(true)
                        Text("近 5 年").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("shortfall.yearRange")
                    ShortfallYearChart(values: visibleYears, selectedYear: $selectedYear, fullscreen: false)
                        .frame(height: 205)
                    if let selectedYear, let selected = visibleYears.first(where: { String($0.year) == selectedYear }) {
                        Text("\(selected.year) 年 · \(ProfileRules.money(selected.amountCents))")
                            .font(.subheadline)
                            .monospacedDigit()
                    } else {
                        Text("按年汇总疑似少缴的个人部分，点选柱形查看金额。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                HStack {
                    Text("年度变化")
                    Spacer()
                    if !yearlyAmounts.isEmpty {
                        Button { showsTrendFullscreen = true } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("全屏查看年度变化")
                        .accessibilityIdentifier("shortfall.expandTrend")
                    }
                }
            }
            Section {
                Picker("排行方式", selection: $ranking) {
                    ForEach(ShortfallRanking.allCases) { option in Text(option.rawValue).tag(option) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("shortfall.rankingMetric")
                ForEach(Array(rankedCompanies.enumerated()), id: \.element.id) { index, company in
                    NavigationLink {
                        PensionShortfallCompanyView(company: company)
                    } label: {
                        rankingRow(company, position: index + 1, maximum: rankingMaximum)
                    }
                }
            } header: {
                HStack {
                    Text("企业排行")
                    Spacer()
                    if !companies.isEmpty {
                        Button { showsRankingFullscreen = true } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("全屏查看企业排行")
                        .accessibilityIdentifier("shortfall.expandRanking")
                    }
                }
            } footer: {
                Text("月均按已比较月份计算；差额率为累计基数差 ÷ 累计应缴基数。有差额月数只作辅助信息，不单独排名。")
            }
            Section("计算口径") {
                Text("按已配置的基数范围估算至上月。首年采用入职月薪，后续年度采用上一年已登记月薪和年终奖的月平均值；个人部分按 8% 计算。工资或实际基数缺失的月份不计金额。此数不是已核实欠缴额，也不是未来少领的养老金。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .neutralPageBackground()
        .navigationTitle("疑似少缴")
        .fullScreenCover(isPresented: $showsTrendFullscreen) {
            ShortfallTrendFullscreen(values: visibleYears, showsAllYears: $showsAllYears, selectedYear: $selectedYear)
        }
        .fullScreenCover(isPresented: $showsRankingFullscreen) {
            ShortfallRankingFullscreen(companies: companies, ranking: $ranking)
        }
    }

    private func summaryNumber(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rankingRow(_ company: PensionShortfallCompany, position: Int, maximum: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(position).")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(company.job.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(ranking.label(company))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                Capsule().fill(.secondary.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule().fill(DashboardStyle.accent)
                            .frame(width: maximum > 0 ? proxy.size.width * (ranking.score(company) ?? 0) / maximum : 0)
                    }
            }
            .frame(height: 5)
            Text("有差额 \(company.positiveCount) / 已比较 \(company.comparableCount) 个月 · 待补 \(company.missingCount) 个月")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

private struct ShortfallYearChart: View {
    let values: [ShortfallYear]
    @Binding var selectedYear: String?
    let fullscreen: Bool

    private var axisYears: [String] {
        let step = max(1, Int(ceil(Double(values.count) / Double(fullscreen ? 10 : 5))))
        return values.enumerated().compactMap { index, item in
            index % step == 0 || index == values.count - 1 ? String(item.year) : nil
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Chart(values) { item in
                BarMark(
                    x: .value("年份", String(item.year)),
                    y: .value("金额（元）", Double(item.amountCents) / 100)
                )
                .foregroundStyle(String(item.year) == selectedYear ? .orange : DashboardStyle.accent)
                .accessibilityLabel("\(item.year) 年，\(ProfileRules.money(item.amountCents))")
            }
            .chartXAxis(.hidden)
            .chartXSelection(value: $selectedYear)
            HStack(spacing: 0) {
                ForEach(Array(axisYears.enumerated()), id: \.element) { index, year in
                    if index > 0 { Spacer(minLength: 2) }
                    Text(year)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityLabel("年度疑似少缴趋势")
    }
}

private struct ShortfallTrendFullscreen: View {
    let values: [ShortfallYear]
    @Binding var showsAllYears: Bool
    @Binding var selectedYear: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel("关闭全屏图表")
                }
                ShortfallYearChart(values: values, selectedYear: $selectedYear, fullscreen: true)
                if let selectedYear, let selected = values.first(where: { String($0.year) == selectedYear }) {
                    Text("\(selected.year) 年 · \(ProfileRules.money(selected.amountCents))")
                        .font(.subheadline).monospacedDigit()
                } else {
                    Text("按年汇总疑似少缴的个人部分 · 单位：元")
                        .font(.caption).foregroundStyle(.secondary)
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

private struct ShortfallRankingFullscreen: View {
    let companies: [PensionShortfallCompany]
    @Binding var ranking: ShortfallRanking
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { proxy in
            let rotated = proxy.size.height > proxy.size.width
            VStack(spacing: 10) {
                HStack {
                    Text("企业排行").font(.headline)
                    Spacer()
                    Picker("排行方式", selection: $ranking) {
                        ForEach(ShortfallRanking.allCases) { option in Text(option.rawValue).tag(option) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel("关闭全屏排行")
                }
                ScrollView {
                    let ordered = ranking.sorted(companies)
                    let maximum = ordered.compactMap { ranking.score($0) }.max() ?? 0
                    VStack(spacing: 12) {
                        ForEach(Array(ordered.enumerated()), id: \.element.id) { index, company in
                            HStack(spacing: 12) {
                                Text("\(index + 1).")
                                    .frame(width: 25, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Text(company.job.displayName)
                                    .frame(width: 150, alignment: .leading)
                                    .lineLimit(1)
                                GeometryReader { bar in
                                    Capsule().fill(.secondary.opacity(0.15))
                                        .overlay(alignment: .leading) {
                                            Capsule().fill(DashboardStyle.accent)
                                                .frame(width: maximum > 0 ? bar.size.width * (ranking.score(company) ?? 0) / maximum : 0)
                                        }
                                }
                                .frame(height: 12)
                                Text(ranking.label(company))
                                    .monospacedDigit()
                                    .frame(width: 110, alignment: .trailing)
                                Text("\(company.positiveCount)/\(company.comparableCount) 月")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.vertical, 8)
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

private struct PensionShortfallCompanyView: View {
    let company: PensionShortfallCompany

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
                            Text(CareerRules.monthLabel(item.month))
                                .font(.headline)
                            Spacer()
                            if let amount = item.personalShortfallCents {
                                Text(ProfileRules.money(amount))
                                    .font(.headline)
                                    .foregroundStyle(amount > 0 ? .orange : .secondary)
                            } else {
                                Text("待补资料")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let reason = item.missing {
                            Text(reason.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("应缴基数 \(ProfileRules.money(item.expectedBaseCents)) · 已记基数 \(ProfileRules.money(item.actualBaseCents))")
                                .font(.subheadline)
                            Text("基数差 \(ProfileRules.money(item.shortfallBaseCents)) · \(item.baseFromProof ? "逐月证明" : "生效记录沿用") · \(item.limitEvidence?.symbol ?? "")\(item.limitEvidence?.title ?? "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
