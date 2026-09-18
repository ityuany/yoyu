import SwiftUI
import SwiftData
import Charts

struct CareerReviewView: View {
    @Query private var jobs: [Employment]
    @Query private var stages: [SalaryStage]
    @Environment(CareerClock.self) private var clock
    @Environment(\.colorScheme) private var colorScheme
    @State private var recent = false
    @State private var byDuration = false
    @State private var selectedDate: Date?
    @State private var showsFullscreenSalary = false
    private let fullscreen: Bool
    private let closeFullscreen: (() -> Void)?

    init(fullscreen: Bool = false, closeFullscreen: (() -> Void)? = nil) {
        self.fullscreen = fullscreen
        self.closeFullscreen = closeFullscreen
    }

    private var summary: CareerReview.Summary { CareerReview.summary(jobs: jobs, stages: stages, now: clock.now) }
    private var domain: ClosedRange<Date> {
        let calendar = ProfileRules.calendar
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: clock.now))!
        let first = summary.tenures.first?.start ?? calendar.date(byAdding: .year, value: -1, to: end)!
        let start = recent ? max(first, calendar.date(byAdding: .year, value: -5, to: end)!) : first
        return min(start, calendar.date(byAdding: .day, value: -1, to: end)!)...end
    }
    private var visiblePay: [CareerReview.Pay] { summary.pay.filter { $0.end > domain.lowerBound && $0.start < domain.upperBound } }

    var body: some View {
        if fullscreen {
            fullscreenSalary
        } else {
            reviewPage
                .fullScreenCover(isPresented: $showsFullscreenSalary) {
                    CareerReviewView(fullscreen: true) { showsFullscreenSalary = false }
                }
        }
    }

    private var reviewPage: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardStyle.sectionSpacing) {
                overview
                salaryChart
                tenureChart.id("tenure")
            }
            .padding(.horizontal, DashboardStyle.pageInset)
            .padding(.vertical, 16)
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--review-tenure") { proxy.scrollTo("tenure", anchor: .top) }
            #endif
        }
        }
        .background(DashboardStyle.background)
        .navigationTitle("职业回顾")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("每一段经历，都在积累").font(.headline)
            HStack(alignment: .top, spacing: 16) {
                metric("累计任职", "\(summary.totalDays.formatted()) 天")
                metric("任职经历", "\(CareerRules.employments(jobs).count) 段")
            }
            Divider()
            let latest = summary.pay.max { $0.end == $1.end ? $0.start < $1.start : $0.end < $1.end }
            HStack(alignment: .top, spacing: 16) {
                metric("最近月薪 · 税前", latest.map { ProfileRules.money($0.cents, compact: true) } ?? "待补全")
                metric("年均薪资增长", summary.annualizedSalaryGrowth.map {
                    $0.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false)))
                } ?? "暂不可算")
            }
            Text("年均增长按首笔至最近记录末日的已录入月薪复合年化，包含空档期；不足一年或首末资料不足时不计算。")
                .font(.caption).foregroundStyle(.secondary)
            Text("任职天数包含入离职当天，空档期不计入，重叠日期仅计一次。")
                .font(.caption).foregroundStyle(.secondary)
        }.dashboardCard()
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var salaryChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                DashboardSectionTitle(title: "薪资变化")
                Spacer()
                Button {
                    showsFullscreenSalary = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.body.weight(.medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(DashboardStyle.accent)
                .accessibilityLabel("全屏查看薪资变化")
                .disabled(visiblePay.isEmpty)
            }
            Picker("时间范围", selection: $recent) {
                Text("全部").tag(false)
                Text("近 5 年").tag(true)
            }.pickerStyle(.segmented)
            if visiblePay.isEmpty {
                ContentUnavailableView("暂无可绘制的薪资", systemImage: "chart.xyaxis.line", description: Text("补充薪资金额与生效日期后，在这里回顾变化。"))
            } else {
                salaryReadout
                salaryPlot.frame(height: 200)
                Text("轻点查看月薪 · 空档期与缺失记录留白")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                DisclosureGroup("薪资记录（\(visiblePay.count)）") {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(visiblePay.reversed()) { pay in payDetail(pay) }
                    }.padding(.top, 12)
                }.font(.subheadline)
            }
            if summary.incompleteJobs > 0 {
                Text("\(summary.incompleteJobs) 段经历的日期或薪资待补全，图表仅展示可确定的记录。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("仅比较税前月薪，不含奖金、股票和其他收入；未来生效的调薪暂不展示。")
                .font(.caption).foregroundStyle(.secondary)
        }.dashboardCard()
    }

    private var fullscreenSalary: some View {
        GeometryReader { geometry in
            let rotated = geometry.size.height > geometry.size.width
            let canvasSize = CGSize(
                width: rotated ? geometry.size.height : geometry.size.width,
                height: rotated ? geometry.size.width : geometry.size.height
            )
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("薪资变化").font(.headline)
                        Text("全部年份 · 税前月薪").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    salaryReadout.frame(maxWidth: 360)
                    Button(action: { closeFullscreen?() }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(.secondary.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭全屏图表")
                }
                if visiblePay.isEmpty {
                    ContentUnavailableView("暂无可绘制的薪资", systemImage: "chart.xyaxis.line")
                } else {
                    salaryPlot.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                HStack {
                    Text("轻点或拖动查看阶段 · 空档期与缺失记录留白")
                    Spacer()
                    Text("不含奖金、股票和其他收入")
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(width: canvasSize.width, height: canvasSize.height)
            .rotationEffect(.degrees(rotated ? 90 : 0))
            .frame(width: geometry.size.width, height: geometry.size.height)

        }
        .background(DashboardStyle.background.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private var axisLabelColor: Color {
        Color(white: colorScheme == .dark ? 0.65 : 0.45)
    }

    private var salaryPlot: some View {
        Chart {
            ForEach(visiblePay) { pay in
                RuleMark(xStart: .value("开始", max(pay.start, domain.lowerBound)), xEnd: .value("结束", min(pay.end, domain.upperBound)), y: .value("月薪", Double(pay.cents) / 100))
                    .foregroundStyle(DashboardStyle.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                if pay.start >= domain.lowerBound, let previous = pay.previousCents {
                    RuleMark(x: .value("调薪", pay.start), yStart: .value("原月薪", Double(previous) / 100), yEnd: .value("月薪", Double(pay.cents) / 100))
                        .foregroundStyle(DashboardStyle.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
            }
            if let selectedDate {
                RuleMark(x: .value("查看日期", selectedDate))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                ForEach(selectedPay) { pay in
                    PointMark(x: .value("查看日期", selectedDate), y: .value("月薪", Double(pay.cents) / 100))
                        .foregroundStyle(DashboardStyle.accent)
                        .symbolSize(65)
                }
            }
        }
        .chartXScale(domain: domain, range: .plotDimension(startPadding: 6, endPadding: 8))
        .chartYScale(domain: 0...salaryUpperBound)
        .chartXAxis {
            AxisMarks(values: .stride(by: domain.upperBound.timeIntervalSince(domain.lowerBound) > 365 * 86_400 ? .year : .month, count: max(1, ProfileRules.calendar.dateComponents([.year], from: domain.lowerBound, to: domain.upperBound).year! / (fullscreen ? 8 : 4)))) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: domain.upperBound.timeIntervalSince(domain.lowerBound) > 365 * 86_400
                             ? .dateTime.year() : .dateTime.month().day())
                            .font(.caption2)
                            .foregroundStyle(axisLabelColor)
                            .padding(.top, 6)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                    .foregroundStyle(.secondary.opacity(0.25))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount >= 10_000
                             ? (amount / 10_000).formatted(.number.precision(.fractionLength(0...1))) + "万"
                             : amount.formatted(.number.precision(.fractionLength(0))))
                            .font(.caption2).monospacedDigit()
                            .foregroundStyle(axisLabelColor)
                            .padding(.trailing, 6)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartGesture { proxy in
            SpatialTapGesture().onEnded { value in
                proxy.selectXValue(at: value.location.x)
            }
            .exclusively(before: DragGesture(minimumDistance: 10).onChanged { value in
                proxy.selectXValue(at: value.location.x)
            })
        }
        .accessibilityLabel("税前月薪变化图，轻点或拖动查看阶段详情")
        .onChange(of: recent) { selectedDate = nil }
    }

    private var selectedPay: [CareerReview.Pay] {
        guard let selectedDate else { return [] }
        return visiblePay.filter { $0.start <= selectedDate && selectedDate < $0.end }
    }

    private var salaryUpperBound: Double {
        max(1, Double(visiblePay.map(\.cents).max() ?? 0) / 100 * 1.15)
    }

    private var salaryReadout: some View {
        let latest = visiblePay.max { $0.end == $1.end ? $0.start < $1.start : $0.end < $1.end }
        let displayed = selectedDate == nil ? latest : selectedPay.first
        return VStack(alignment: .leading, spacing: 5) {
            Text(selectedDate.map { CareerRules.dateLabel($0) } ?? "最近已录入 · 税前月薪")
                .font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(displayed.map { ProfileRules.money($0.cents, compact: true) } ?? "暂无记录")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                if displayed != nil {
                    Text("/ 月").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if selectedDate != nil {
                    Button { selectedDate = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("取消图表选择")
                }
            }
            Text(selectedPay.count > 1 ? "该日有 \(selectedPay.count) 段任职，图中分别标示" : displayed.map { $0.name + (fullscreen ? changeLabel($0) : "") } ?? "该日期没有已录入的适用薪资")
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func payDetail(_ pay: CareerReview.Pay) -> some View {
        NavigationLink(value: CareerDestination.employment(pay.jobID)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(pay.name).font(.subheadline.weight(.medium))
                    Spacer()
                    Text(ProfileRules.money(pay.cents)).font(.subheadline.weight(.semibold))
                }
                Text("\(CareerRules.dateLabel(pay.start))起" + changeLabel(pay))
                    .font(.caption).foregroundStyle(.secondary)
            }.foregroundStyle(.primary)
        }.buttonStyle(.plain)
    }

    private func changeLabel(_ pay: CareerReview.Pay) -> String {
        guard let previous = pay.previousCents, previous > 0 else { return "" }
        let percent = Double(pay.cents - previous) / Double(previous) * 100
        return String(format: " · 较上一阶段 %+.1f%%", percent)
    }

    private var tenureChart: some View {
        let tenures = byDuration ? summary.tenures.sorted { $0.days > $1.days } : summary.tenures
        let first = summary.tenures.first?.start ?? clock.now
        let last = summary.tenures.map(\.end).max() ?? clock.now
        let span = max(1, last.timeIntervalSince(first))
        let maxDays = max(1, summary.tenures.map(\.days).max() ?? 1)
        return VStack(alignment: .leading, spacing: 16) {
            DashboardSectionTitle(title: "时间花在哪里")
            Picker("任职排列", selection: $byDuration) {
                Text("按时间").tag(false)
                Text("按时长").tag(true)
            }.pickerStyle(.segmented)
            if tenures.isEmpty {
                Text("补充入职日期后查看任职时间轴。").font(.subheadline).foregroundStyle(.secondary)
            } else {
                if !byDuration {
                    HStack {
                        Text(first, format: .dateTime.year().month())
                        Spacer()
                        Text(last.addingTimeInterval(-1), format: .dateTime.year().month())
                    }.font(.caption).foregroundStyle(.secondary)
                }
                ForEach(tenures) { tenure in
                    NavigationLink(value: CareerDestination.employment(tenure.id)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(tenure.name).font(.subheadline.weight(.medium))
                                Spacer(minLength: 12)
                                Text("\(tenure.days.formatted()) 天").font(.subheadline).monospacedDigit()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                            GeometryReader { geometry in
                                let offset = byDuration ? 0 : tenure.start.timeIntervalSince(first) / span
                                let fraction = byDuration ? Double(tenure.days) / Double(maxDays) : tenure.end.timeIntervalSince(tenure.start) / span
                                Capsule().fill(DashboardStyle.accent.opacity(0.08))
                                Capsule().fill(DashboardStyle.accent.opacity(0.7))
                                    .frame(width: min(geometry.size.width * (1 - offset), max(3, geometry.size.width * fraction)))
                                    .offset(x: geometry.size.width * offset)
                            }.frame(height: 8).accessibilityHidden(true)
                            Text("\(CareerRules.dateLabel(tenure.start))—\(CareerRules.dateLabel(tenure.end.addingTimeInterval(-1)))")
                                .font(.caption).foregroundStyle(.secondary)
                        }.foregroundStyle(.primary).padding(.vertical, 4)
                    }.buttonStyle(.plain)
                }
            }
            Text(byDuration ? "按任职天数从长到短排列。点击公司查看详情。" : "所有公司使用同一时间刻度，空档期自然留白。点击公司查看详情。")
                .font(.caption).foregroundStyle(.secondary)
        }.dashboardCard()
    }
}
