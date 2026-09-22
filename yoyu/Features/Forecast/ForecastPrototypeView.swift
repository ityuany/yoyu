import SwiftUI
import Charts

/// 独立交互原型：所有数字均为内存中的示例，不读取或写入业务数据。
struct ForecastPrototypeView: View {
    @State private var scenario = PrototypeScenario.working
    @State private var assumptions = PrototypeAssumptions()
    @State private var duration = 12
    @State private var selectedMonth: Int? = nil
    @State private var editing = false
    @State private var fullscreen = false
    private let accent = Color.teal
    private var points: [PrototypeMonth] { assumptions.months(scenario: scenario, count: duration) }
    private var selected: PrototypeMonth { points[min(max((selectedMonth ?? duration) - 1, 0), points.count - 1)] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Label("设计预览 · 示例数据", systemImage: "sparkles")
                    Spacer()
                    Text("不保存到个人账本")
                }.font(.caption).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Text("给未来，多一点底气").font(.title2.bold())
                    Text("试试不同的生活选择，看看手里的钱如何变化。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    ForEach(PrototypeScenario.allCases) { item in
                        Button { scenario = item } label: {
                            VStack(spacing: 9) {
                                Image(systemName: item.icon).font(.title3)
                                Text(item.rawValue).font(.subheadline.weight(.semibold))
                            }.frame(maxWidth: .infinity).padding(.vertical, 17)
                                .foregroundStyle(scenario == item ? accent : .secondary)
                                .background(scenario == item ? accent.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(scenario == item ? accent : .clear, lineWidth: 1.5))
                        }.buttonStyle(.plain).accessibilityIdentifier("prototype.scenario.\(item.id)")
                            .accessibilityAddTraits(scenario == item ? .isSelected : [])
                    }
                }
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label("\(duration) 个月后 · 可用资金", systemImage: "wallet.bifold")
                            .font(.subheadline)
                        Spacer()
                        Text(scenario.rawValue).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(money(points.last!.balance)).font(.system(size: 38, weight: .semibold, design: .rounded))
                        .accessibilityIdentifier("prototype.balance")
                    Text(points.contains { $0.balance < 0 } ? "示例情景下，资金将在第 \(points.first { $0.balance < 0 }!.id) 个月出现缺口。" : "示例情景下，未来 \(duration) 个月的日常开支均有覆盖。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Divider()
                    HStack {
                        summary("起始资金", money(assumptions.funds))
                        Spacer()
                        summary("每月开支", money(assumptions.spending))
                        Spacer()
                        Button("调整假设") { editing = true }.font(.subheadline.bold())
                            .accessibilityIdentifier("prototype.edit")
                    }
                }.padding(20).background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 24))
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("资金走势").font(.headline)
                        Spacer()
                        Button { fullscreen = true } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44)
                        }.accessibilityLabel("全屏查看资金走势").accessibilityIdentifier("prototype.expand")
                    }
                    Picker("预测范围", selection: $duration) {
                        Text("1 年").tag(12)
                        Text("3 年").tag(36)
                        Text("5 年").tag(60)
                    }.pickerStyle(.segmented)
                    chartSelection
                    chart.frame(height: 195)
                    Text("轻点或拖动图表查看月份 · 金额单位：万元")
                        .font(.caption).foregroundStyle(.secondary)
                }.dashboardCard()
                VStack(alignment: .leading, spacing: 18) {
                    Text("未来的关键节点").font(.headline)
                    milestone("现在", "从 \(money(assumptions.funds)) 出发", "这里是你探索不同生活方式的起点。", "flag")
                    if scenario == .pause {
                        milestone("第 \(assumptions.breakMonths + 1) 个月", "回到工作节奏", "恢复示例月收入 \(money(assumptions.income))。", "briefcase")
                    }
                    if let gap = points.first(where: { $0.balance < 0 }) {
                        milestone("第 \(gap.id) 个月", "需要补充资金", "可以试着减少开支，或调整工作计划。", "exclamationmark.circle")
                    } else {
                        milestone("第 \(duration) 个月", "留有余地", "预计剩余 \(money(points.last!.balance)) 可用资金。", "leaf")
                    }
                }.dashboardCard()
                NavigationLink {
                    List(points) { month in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack { Text("第 \(month.id) 个月").font(.headline); Spacer(); Text(money(month.balance)).bold() }
                            HStack { Text("收入 \(money(month.income))"); Spacer(); Text("开支 \(money(assumptions.spending))") }
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 6)
                    }.navigationTitle("逐月预览")
                } label: {
                    HStack { Label("逐月看看", systemImage: "calendar"); Spacer(); Image(systemName: "chevron.right") }.dashboardCard()
                }.buttonStyle(.plain).accessibilityIdentifier("prototype.details")
                Text("这是用于讨论布局与交互的独立原型。金额按固定月收入与开支演示，尚未包含投资收益、负债、税费或真实财务记录。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("预测实验室").navigationBarTitleDisplayMode(.inline).tint(accent)
        .sheet(isPresented: $editing) {
            PrototypeAssumptionsEditor(draft: assumptions) { assumptions = $0 }
        }
        .fullScreenCover(isPresented: $fullscreen) {
            GeometryReader { geometry in
                let rotate = geometry.size.height > geometry.size.width
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("资金走势 · \(scenario.rawValue) · \(duration / 12) 年").font(.headline)
                        Spacer()
                        Button("关闭", systemImage: "xmark") { fullscreen = false }
                            .frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("prototype.close")
                    }
                    chartSelection
                    chart
                }.padding(24)
                    .frame(width: rotate ? geometry.size.height : geometry.size.width, height: rotate ? geometry.size.width : geometry.size.height)
                    .rotationEffect(.degrees(rotate ? 90 : 0))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }.background(Color(uiColor: .systemBackground)).tint(accent)
        }
    }

    private var chartSelection: some View {
        HStack {
            Text("第 \(selected.id) 个月").foregroundStyle(.secondary)
            Spacer()
            Text(money(selected.balance)).bold().monospacedDigit()
        }.font(.subheadline)
    }
    private var chart: some View {
        Chart(points) { point in
            AreaMark(x: .value("月份", point.id), yStart: .value("零", 0), yEnd: .value("资金", point.balance / 10000))
                .foregroundStyle(.linearGradient(colors: [accent.opacity(0.22), accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("月份", point.id), y: .value("资金", point.balance / 10000)).foregroundStyle(accent).lineStyle(StrokeStyle(lineWidth: 3))
            RuleMark(y: .value("零", 0)).foregroundStyle(.secondary.opacity(0.4)).lineStyle(StrokeStyle(dash: [4]))
            if point.id == selected.id {
                PointMark(x: .value("月份", point.id), y: .value("资金", point.balance / 10000)).foregroundStyle(accent).symbolSize(55)
            }
        }.chartXSelection(value: $selectedMonth)
            .chartXAxis { AxisMarks(values: [1, duration / 2, duration]) }
            .accessibilityLabel("示例资金走势，\(duration) 个月，期末\(money(points.last!.balance))")
    }
    private func summary(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.subheadline.bold()) }
    }
    private func milestone(_ time: String, _ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(accent).frame(width: 34, height: 34).background(accent.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(time).font(.caption).foregroundStyle(.secondary)
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func money(_ value: Double) -> String { "¥" + value.formatted(.number.precision(.fractionLength(0))) }
}

private enum PrototypeScenario: String, CaseIterable, Identifiable {
    case working = "继续工作", pause = "休息一阵", stop = "不再工作"
    var id: String { switch self { case .working: "working"; case .pause: "pause"; case .stop: "stop" } }
    var icon: String { switch self { case .working: "briefcase"; case .pause: "cup.and.saucer"; case .stop: "sun.horizon" } }
}
private struct PrototypeMonth: Identifiable { let id: Int; let balance: Double; let income: Double }
private struct PrototypeAssumptions {
    var funds = 300000.0
    var income = 18000.0
    var spending = 10000.0
    var breakMonths = 6
    func months(scenario: PrototypeScenario, count: Int) -> [PrototypeMonth] {
        var balance = funds
        return (1...count).map { month in
            let pay = scenario == .working || (scenario == .pause && month > breakMonths) ? income : 0
            balance += pay - spending
            return PrototypeMonth(id: month, balance: balance, income: pay)
        }
    }
}
private struct PrototypeAssumptionsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: PrototypeAssumptions
    var apply: (PrototypeAssumptions) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("只调整本次页面的示例，离开原型后重置。").foregroundStyle(.secondary) }
                Section("手里的钱") { slider("起始资金", value: $draft.funds, range: 0...1000000, step: 10000) }
                Section("每月收支") {
                    slider("工作月收入", value: $draft.income, range: 0...50000, step: 1000)
                    slider("每月开支", value: $draft.spending, range: 1000...30000, step: 1000)
                }
                Section("休息一阵") {
                    Stepper("休息 \(draft.breakMonths) 个月", value: $draft.breakMonths, in: 1...36)
                    Text("选择「休息一阵」时生效，休息结束后恢复工作收入。").font(.caption).foregroundStyle(.secondary)
                }
                Section { Button("恢复默认示例") { draft = PrototypeAssumptions() } }
            }.navigationTitle("调整假设").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("应用") { apply(draft); dismiss() } }
                }
        }.tint(.teal)
    }
    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading) {
            HStack { Text(title); Spacer(); Text("¥" + value.wrappedValue.formatted(.number.precision(.fractionLength(0)))).foregroundStyle(.secondary) }
            Slider(value: value, in: range, step: step).accessibilityLabel(title)
        }
    }
}

#Preview { NavigationStack { ForecastPrototypeView() } }
