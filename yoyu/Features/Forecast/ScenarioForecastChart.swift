import SwiftUI
import Charts

struct ScenarioForecastChart: View {
    let months: [ScenarioForecastMonth]
    let scenario: ForecastScenario
    let balanceMode: Bool
    private var first: Date { months.first!.calculationStart ?? months.first!.date }
    private var end: Date { ProfileRules.calendar.date(byAdding: .month, value: 1, to: months.last!.date)! }
    private func monthEnd(_ month: Date) -> Date { ProfileRules.calendar.date(byAdding: .day, value: -1, to: ProfileRules.calendar.date(byAdding: .month, value: 1, to: month)!)! }

    private var yDomain: ClosedRange<Double> {
        let values = balanceMode
            ? ([scenario.openingFunds].compactMap { $0 } + months.compactMap(\.balance))
            : months.flatMap { [$0.income, $0.expense.total].compactMap { $0 } }
        let lower = min(0, Double(values.min() ?? 0) / 100)
        let upper = max(100, Double(values.max() ?? 0) / 100)
        let padding = max(100, (upper - lower) * 0.1)
        return (lower < 0 ? lower - padding : 0)...(upper + padding)
    }
    var body: some View {
        Chart {
            if scenario.mode != .employed {
                let lower = max(first, scenario.breakStart)
                let upper = min(end, scenario.mode == .temporaryBreak ? scenario.returnDate : end)
                if lower < upper {
                    RectangleMark(xStart: .value("开始", lower), xEnd: .value("结束", upper))
                        .foregroundStyle(Color.orange.opacity(0.09))
                }
                if scenario.breakStart >= first && scenario.breakStart < end {
                    RuleMark(x: .value("失业", scenario.breakStart)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(Color.orange.opacity(0.7))
                }
                if scenario.mode == .temporaryBreak && scenario.returnDate >= first && scenario.returnDate < end {
                    RuleMark(x: .value("再就业", scenario.returnDate)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(DashboardStyle.cash.opacity(0.7))
                }
            }
            if balanceMode {
                RuleMark(y: .value("资金底线", 0)).foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3]))
                if let funds = scenario.openingFunds {
                    LineMark(x: .value("日期", first), y: .value("元", Double(funds) / 100))
                        .foregroundStyle(DashboardStyle.cash)
                }
                ForEach(months) { month in
                    if let balance = month.balance {
                        LineMark(x: .value("日期", monthEnd(month.date)), y: .value("元", Double(balance) / 100))
                            .foregroundStyle(DashboardStyle.cash)
                        PointMark(x: .value("日期", monthEnd(month.date)), y: .value("元", Double(balance) / 100))
                            .symbolSize(months.count > 12 ? 8 : 22).foregroundStyle(DashboardStyle.cash)
                    }
                }
            } else {
                ForEach(months) { month in
                    if let income = month.income {
                        BarMark(x: .value("月份", month.date, unit: .month), y: .value("元", Double(income) / 100))
                            .foregroundStyle(by: .value("类型", "收入")).position(by: .value("类型", "收入"))
                    }
                    if let expense = month.expense.total {
                        BarMark(x: .value("月份", month.date, unit: .month), y: .value("元", Double(expense) / 100))
                            .foregroundStyle(by: .value("类型", "支出")).position(by: .value("类型", "支出"))
                    }
                }
            }
        }
        .chartXScale(domain: first...end)
        .chartYScale(domain: yDomain)
        .chartLegend(balanceMode ? .hidden : .visible)
        .chartForegroundStyleScale(["收入": DashboardStyle.cash, "支出": DashboardStyle.stock])
        .chartXAxis { AxisMarks(values: .stride(by: .month, count: months.count > 12 ? 12 : 3)) { _ in
            AxisGridLine(); AxisValueLabel(format: .dateTime.year(.twoDigits).month(.twoDigits))
        } }
        .chartYAxis { AxisMarks(position: .leading) { value in
            AxisGridLine()
            AxisValueLabel {
                if let amount = value.as(Double.self) {
                    Text(abs(amount) >= 10_000 ? (amount / 10_000).formatted(.number.precision(.fractionLength(0...1))) + "万" : amount.formatted(.number.precision(.fractionLength(0))))
                }
            }
        } }
        .chartYAxisLabel("元")
    }
}
