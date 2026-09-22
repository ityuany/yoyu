import SwiftUI
import Charts

struct RunwayChart: View {
    let result: RunwayResult
    let plan: RunwayPlan
    let years: Int
    @Binding var selection: Date?
    private var points: [RunwayPoint] {
        let upper = years == 0 ? result.end : ProfileRules.calendar.date(byAdding: .year, value: years, to: result.origin)!
        var seen = Set<Date>()
        return result.points.filter { $0.date >= result.origin && $0.date <= upper && seen.insert($0.date).inserted }
    }
    var body: some View {
        Chart {
            ForEach(points) { p in
                AreaMark(x: .value("日期", p.date), y: .value("资产", Double(p.total) / 100))
                    .foregroundStyle(LinearGradient(colors: [DashboardStyle.cash.opacity(0.25), DashboardStyle.cash.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("日期", p.date), y: .value("资产", Double(p.total) / 100))
                    .foregroundStyle(DashboardStyle.cash).lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            if let back = plan.returnDate, plan.mode == .temporary, let first = points.first, let last = points.last, back >= first.date && back <= last.date {
                RuleMark(x: .value("重新就业", back)).foregroundStyle(.secondary).lineStyle(StrokeStyle(dash: [4, 4]))
                    .annotation(position: .top) { Text("重新就业").font(.caption2).foregroundStyle(.secondary) }
            }
            if let selection {
                RuleMark(x: .value("选中日期", selection)).foregroundStyle(.secondary.opacity(0.5))
            }
        }
        .chartXSelection(value: $selection)
        .chartYScale(domain: .automatic(includesZero: true))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                AxisValueLabel { if let number = value.as(Double.self) { Text(number >= 10000 ? "\(number / 10000, specifier: "%.0f")万" : "\(number, specifier: "%.0f")").font(.caption2) } }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        let parts = ProfileRules.calendar.dateComponents([.year, .month], from: date)
                        Text("\(String(parts.year ?? 0)).\(parts.month ?? 0)")
                    }
                }
            }
        }
        .accessibilityLabel("资产余额趋势，可选中日期查看资产构成")
    }
}

struct RunwayFullscreen: View {
    let result: RunwayResult
    let plan: RunwayPlan
    @Binding var years: Int
    @Binding var selection: Date?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        GeometryReader { proxy in
            let rotated = proxy.size.height > proxy.size.width
            VStack(spacing: 12) {
                HStack {
                    Text("资产余额趋势").font(.headline)
                    Spacer()
                    Picker("查看范围", selection: $years) { Text("1 年").tag(1); Text("5 年").tag(5); Text("完整过程").tag(0) }.pickerStyle(.segmented).frame(width: 240)
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel("关闭全屏图表").accessibilityIdentifier("runway.closeChart")
                }
                RunwayChart(result: result, plan: plan, years: years, selection: $selection)
            }
            .padding(24)
            .frame(width: rotated ? proxy.size.height : proxy.size.width, height: rotated ? proxy.size.width : proxy.size.height)
            .background(Color(uiColor: .systemBackground))
            .rotationEffect(.degrees(rotated ? 90 : 0))
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}
