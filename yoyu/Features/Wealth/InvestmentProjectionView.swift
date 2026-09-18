import SwiftUI
import Charts

struct InvestmentProjectionView: View {
    @State private var principal: String
    @State private var annualRate: String
    @State private var selectedMonths = 12
    @State private var customDuration = ""
    @State private var customUnit = 1
    @State private var mode: InvestmentInterestMode = .simple
    @FocusState private var isEditing: Bool

    init(principal: Int64?, annualRate: Int64?) {
        _principal = State(initialValue: principal.map { ProfileRules.input($0) } ?? "")
        _annualRate = State(initialValue: annualRate.map { ProfileRules.input($0) } ?? "")
    }

    private var months: Int? {
        if selectedMonths != 0 { return selectedMonths }
        guard let value = Int(customDuration), value > 0, value <= 1200 / customUnit else { return nil }
        return value * customUnit
    }
    private var principalValue: Int64? { ProfileRules.scaledValue(principal, maximum: ProfileRules.maximumMoneyCents) }
    private var rateValue: Int64? { ProfileRules.annualReturnRate(annualRate) }
    private func result(at month: Int, mode: InvestmentInterestMode? = nil) -> InvestmentProjection? {
        InvestmentProjection.calculate(principal: principalValue, rate: rateValue, months: month, mode: mode ?? self.mode)
    }
    private var projection: InvestmentProjection? { months.flatMap { result(at: $0) } }
    private var validation: String {
        if principalValue == nil { return "请填写有效本金，最多两位小数。" }
        if rateValue == nil { return "年化收益率请输入 -100% 至 100%，最多两位小数。" }
        if months == nil { return "自定义期限请输入整数，范围为 1–1200 个月或 1–100 年。" }
        return "测算金额超出支持范围，请缩短期限或调整本金、收益率。"
    }
    private var detailMonths: [Int] {
        guard let months else { return [] }
        let step = months <= 12 ? 1 : 12
        return Array(Set(Array(stride(from: step, through: months, by: step)) + [months])).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                resultCard
                settingsCard
                if let months, projection != nil {
                    trendCard(months: months)
                    detailsCard
                }
                Text("假设年化收益率保持不变，从今天起测算，不含追加投入、取出及税费。单利收益不再投入；复利每满一年复投，剩余月份按比例计息。负收益最多损失本金。结果仅为情景测算。")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(DashboardStyle.pageInset)
        }
        .background(DashboardStyle.background)
        .navigationTitle("收益测算")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { isEditing = false }
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("预计累计收益", systemImage: "chart.line.uptrend.xyaxis")
                Spacer()
                Text(mode.rawValue).font(.caption.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(DashboardStyle.investment.opacity(0.12), in: Capsule())
            }
            .font(.subheadline).foregroundStyle(DashboardStyle.investment)
            if let projection, let months {
                DashboardAmount(value: ProfileRules.money(projection.earningsCents))
                HStack {
                    Text("\(InvestmentProjection.duration(months))后本息合计")
                    Spacer()
                    Text(ProfileRules.money(projection.totalCents)).monospacedDigit()
                }.font(.subheadline)
                if mode == .compound, let simple = result(at: months, mode: .simple) {
                    Text("较单利收益差额 \(ProfileRules.money(projection.earningsCents - simple.earningsCents))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("待完善测算条件").font(.title3.weight(.semibold))
                Text(validation).font(.subheadline).foregroundStyle(.secondary)
            }
        }.dashboardCard(highlighted: true)
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("测算条件").font(.headline)
            inputRow("本金", text: $principal, unit: "元")
            Divider()
            inputRow("年化收益率", text: $annualRate, unit: "%")
            Text("仅用于本次测算，不修改已保存的理财配置。")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("预测期限").font(.subheadline.weight(.medium))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(InvestmentProjection.presets + [0], id: \.self) { month in
                    Button {
                        selectedMonths = month
                        isEditing = false
                    } label: {
                        Text(month == 0 ? "自定义" : InvestmentProjection.duration(month))
                            .font(.subheadline.weight(selectedMonths == month ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(selectedMonths == month ? Color(uiColor: .systemBackground) : Color.primary)
                            .background(selectedMonths == month ? DashboardStyle.accent : Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedMonths == month ? [.isSelected] : [])
                }
            }
            if selectedMonths == 0 {
                HStack {
                    TextField("输入期限", text: $customDuration)
                        .keyboardType(.numberPad).focused($isEditing)
                        .accessibilityLabel("自定义期限")
                    Picker("期限单位", selection: $customUnit) {
                        Text("个月").tag(1)
                        Text("年").tag(12)
                    }.pickerStyle(.segmented).frame(width: 130)
                }
            }
            Picker("计算方式", selection: $mode) {
                ForEach(InvestmentInterestMode.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Text(mode == .simple ? "收益不再投入，按初始本金计算。" : "每满一年将收益计入本金，剩余月份按比例计息。")
                .font(.caption).foregroundStyle(.secondary)
        }.dashboardCard()
    }

    private func inputRow(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("待填写", text: text)
                .keyboardType(title == "本金" ? .decimalPad : .numbersAndPunctuation)
                .multilineTextAlignment(.trailing).focused($isEditing)
                .accessibilityLabel(title)
            Text(unit).foregroundStyle(.secondary)
        }.font(.subheadline)
    }

    private func trendCard(months: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("累计收益走势").font(.headline)
            Chart {
                ForEach(0...months, id: \.self) { month in
                    if let point = result(at: month) {
                        LineMark(x: .value("月数", month), y: .value("收益（元）", Double(point.earningsCents) / 100))
                            .foregroundStyle(DashboardStyle.investment)
                    }
                }
            }
            .chartXAxisLabel("月数")
            .chartYAxisLabel("元")
            .frame(height: 180)
            .accessibilityLabel("\(InvestmentProjection.duration(months))累计收益走势")
        }.dashboardCard()
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("收益明细").font(.headline)
            HStack {
                Text("期限")
                Spacer()
                Text("累计收益 / 本息合计")
            }.font(.caption).foregroundStyle(.secondary)
            ForEach(detailMonths, id: \.self) { month in
                if let value = result(at: month) {
                    HStack {
                        Text(InvestmentProjection.duration(month)).font(.subheadline)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(ProfileRules.money(value.earningsCents)).foregroundStyle(DashboardStyle.investment)
                            Text(ProfileRules.money(value.totalCents)).foregroundStyle(.secondary)
                        }.font(.subheadline).monospacedDigit()
                    }
                    if month != detailMonths.last { Divider() }
                }
            }
        }.dashboardCard()
    }
}
