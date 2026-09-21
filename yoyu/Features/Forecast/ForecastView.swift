import SwiftUI
import SwiftData
import Charts

struct ForecastView: View {
    @Query private var expenses: [RecurringExpense]
    @Query private var liabilities: [LiabilityAccount]
    @Environment(CareerClock.self) private var clock
    @State private var duration = 12
    @State private var showsFullscreenChart = false
    private var months: [ExpenseForecastMonth] {
        ExpenseForecast.months(expenses: expenses, liabilities: liabilities, after: clock.now, count: duration)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("把未来的开支，提前看清").font(.title2.bold())
                        Text("从已有计划出发，看看每个月需要准备多少。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Picker("预测范围", selection: $duration) {
                        Text("未来 12 个月").tag(12)
                        Text("3 年").tag(36)
                        Text("5 年").tag(60)
                    }.pickerStyle(.segmented).accessibilityIdentifier("forecast.range")
                    if expenses.isEmpty && liabilities.isEmpty {
                        ContentUnavailableView("先安排一项开支", systemImage: "calendar.badge.plus", description: Text("添加生活费、租金等计划后，即可查看未来走势。"))
                        NavigationLink("配置预计支出") { ExpectedExpenseView() }
                    } else {
                        let values = months
                        overview(values)
                        trend(values)
                        insights(values)
                        NavigationLink { ForecastMonthList(months: values) } label: {
                            HStack {
                                Label("查看逐月明细", systemImage: "calendar")
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.bold())
                            }.dashboardCard()
                        }.buttonStyle(.plain).accessibilityIdentifier("forecast.details")
                        assumptions
                    }
                }.padding(DashboardStyle.pageInset)
            }
            .background(DashboardStyle.background)
            .dashboardTabRoot(title: "预测")
            .fullScreenCover(isPresented: $showsFullscreenChart) {
                fullscreenChart(months)
            }
        }
    }

    private func overview(_ values: [ExpenseForecastMonth]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("预计总支出", systemImage: "calendar.badge.clock")
                Spacer()
                Text("按当前计划").font(.caption).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(DashboardStyle.cash.opacity(0.12), in: Capsule())
            }.font(.subheadline).foregroundStyle(.secondary)
            DashboardAmount(value: ExpenseForecast.total(values).map { ProfileRules.money($0) } ?? "待核对")
                .accessibilityIdentifier("forecast.total")
            Text("\(ExpenseRules.monthLabel(values[0].date)) — \(ExpenseRules.monthLabel(values[values.count - 1].date))")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack(alignment: .top) {
                metric("平均每月", value: ExpenseForecast.total(values).map { ProfileRules.money($0 / Int64(values.count)) } ?? "待核对")
                Spacer()
                if ExpenseForecast.total(values) != nil, let peak = values.max(by: { ($0.total ?? 0) < ($1.total ?? 0) }) {
                    metric("最高月份 · \(shortMonth(peak.date))", value: peak.total.map { ProfileRules.money($0) } ?? "待核对")
                }
            }
        }.dashboardCard(highlighted: true)
    }
    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
    }
    private func shortMonth(_ date: Date) -> String {
        let c = ExpenseRules.calendar.dateComponents([.year, .month], from: date)
        return "\(c.year!)年\(c.month!)月"
    }
    private func trend(_ values: [ExpenseForecastMonth]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(duration == 12 ? "每月支出走势" : "每年支出走势").font(.headline)
                Spacer()
                Button { showsFullscreenChart = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.body.weight(.medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("全屏查看支出走势")
                .accessibilityIdentifier("forecast.expand")
                .disabled(ExpenseForecast.total(values) == nil)
            }
            if ExpenseForecast.total(values) != nil {
                plot(values).frame(height: 210)
                Text(duration == 12 ? "按发生月份计入，年付费用不作月均摊。" : "每年为从预测起点开始的连续 12 个月。")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("部分计划无法计算，请先核对预计支出中的记录。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }.dashboardCard()
    }
    private func plot(_ values: [ExpenseForecastMonth]) -> some View {
        Chart {
            ForEach(0..<(duration == 12 ? 12 : duration / 12), id: \.self) { index in
                let slice = duration == 12 ? [values[index]] : Array(values[(index * 12)..<(index * 12 + 12)])
                let label = duration == 12 ? "\(ExpenseRules.calendar.component(.month, from: slice[0].date))月" : "第\(index + 1)年"
                BarMark(x: .value("期间", label), y: .value("元", Double(LiabilityRules.sum(slice.compactMap(\.daily)) ?? 0) / 100))
                    .foregroundStyle(by: .value("类型", "日常开支"))
                BarMark(x: .value("期间", label), y: .value("元", Double(LiabilityRules.sum(slice.compactMap(\.repayment)) ?? 0) / 100))
                    .foregroundStyle(by: .value("类型", "负债还款"))
            }
        }
        .chartForegroundStyleScale(["日常开支": DashboardStyle.cash, "负债还款": DashboardStyle.stock])
        .chartYAxisLabel("元")
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount >= 10_000
                             ? (amount / 10_000).formatted(.number.precision(.fractionLength(0...1))) + "万"
                             : amount.formatted(.number.precision(.fractionLength(0))))
                            .fixedSize()
                    }
                }
            }
        }
    }

    private func fullscreenChart(_ values: [ExpenseForecastMonth]) -> some View {
        GeometryReader { geometry in
            let rotated = geometry.size.height > geometry.size.width
            let canvas = CGSize(width: rotated ? geometry.size.height : geometry.size.width,
                                height: rotated ? geometry.size.width : geometry.size.height)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(duration == 12 ? "每月支出走势" : "每年支出走势").font(.headline)
                        Text("\(duration == 12 ? "未来 12 个月" : "未来 \(duration / 12) 年") · \(ExpenseRules.monthLabel(values[0].date)) — \(ExpenseRules.monthLabel(values[values.count - 1].date))")
                            .font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("forecast.fullscreen.range")
                    }
                    Spacer(minLength: 8)
                    Button { showsFullscreenChart = false } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(.secondary.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭全屏图表")
                    .accessibilityIdentifier("forecast.fullscreen.close")
                }
                plot(values).frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(duration == 12 ? "按发生月份计入，年付费用不作月均摊。" : "每年为从预测起点开始的连续 12 个月。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(width: canvas.width, height: canvas.height)
            .rotationEffect(.degrees(rotated ? 90 : 0))
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(DashboardStyle.background.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private func insights(_ values: [ExpenseForecastMonth]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("留意这些变化", systemImage: "sparkle").font(.headline)
            if let first = values.first, let last = values.last, let a = first.total, let b = last.total, a != b {
                Text("期末月比起始月\(b > a ? "增加" : "减少") \(ProfileRules.money(abs(b - a)))。")
                    .font(.subheadline)
            } else {
                Text("已有计划会按各自的周期和结束日期展开。") .font(.subheadline)
            }
            let ending = ExpenseRules.records(expenses).filter { record in
                guard let end = record.plan?.end else { return false }
                return end >= values[0].date && ExpenseRules.month(end) <= values[values.count - 1].date
            }
            ForEach(ending) { record in
                if let plan = record.plan, let end = plan.end {
                    Text("\(plan.name)将于\(shortMonth(end))结束；后续同类开支尚未计入。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if ExpectedExpenseRules.missingBills(liabilities) {
                Text("部分信用卡账单未录入，仅包含已知还款。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }.dashboardCard()
    }
    private var assumptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("这份预测如何计算").font(.subheadline.weight(.semibold))
            Text("从下个月起按完整月份推算。沿用现有金额、利率与周期，包含还款本金及利息／费用；未录入的临时开支、未来涨价和新消费不在其中。未设置结束日期的开支持续计入。预测不会扣减现金，也不代表实际消费流水。")
                .font(.caption).foregroundStyle(.secondary)
            NavigationLink("查看和调整已有计划") { ExpectedExpenseView() }
                .font(.subheadline)
        }.padding(.horizontal, 4)
    }
}

private struct ForecastMonthList: View {
    let months: [ExpenseForecastMonth]
    var body: some View {
        List {
            Section {
                ForEach(months) { month in
                    NavigationLink {
                        ExpectedExpenseView(initialMonth: month.date)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(ExpenseRules.monthLabel(month.date))
                                Spacer()
                                Text(month.total.map { ProfileRules.money($0) } ?? "待核对").monospacedDigit()
                            }
                            Text("日常 \(month.daily.map { ProfileRules.money($0) } ?? "待核对") · 还款 \(month.repayment.map { ProfileRules.money($0) } ?? "待核对")")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                }
            } footer: { Text("按当前已知计划推算，不代表已经发生的消费。") }
        }
        .navigationTitle("逐月明细")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

#if DEBUG
struct ForecastTestHost: View {
    @State private var container: ModelContainer?
    @State private var clock = CareerClock()
    var body: some View {
        Group {
            if let container {
                ForecastView().modelContainer(container).environment(clock)
            } else { ProgressView().task { prepare() } }
        }
    }
    private func prepare() {
        do {
            let schema = Schema([RecurringExpense.self, LiabilityAccount.self])
            let sample = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
            clock.now = ProfileRules.date(2026, 9, 22)
            let plans = [
                ExpensePlan(name: "生活费", amount: 3000_00, start: ProfileRules.date(2026, 9, 1)),
                ExpensePlan(name: "租金", amount: 2000_00, start: ProfileRules.date(2026, 9, 1), end: ProfileRules.date(2027, 3, 31)),
                ExpensePlan(name: "年度保险", amount: 6000_00, frequency: .yearly, start: ProfileRules.date(2026, 12, 10), spreadAcrossMonth: false, dueDay: 10)
            ]
            for plan in plans {
                let record = RecurringExpense()
                record.planData = try JSONEncoder().encode(plan)
                sample.mainContext.insert(record)
            }
            try sample.mainContext.save()
            container = sample
        } catch { assertionFailure("Forecast fixture failed: \(error)") }
    }
}
#endif
