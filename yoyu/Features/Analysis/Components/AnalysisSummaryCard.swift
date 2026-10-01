import SwiftUI

/// 概览只缩写显示金额，详情与无障碍读数保留精确人民币金额。
enum AnalysisOverviewStyle {
    static let accent = Color("AnalysisOverviewAccent")
    static let muted = AppTheme.secondaryText

    static var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color("AnalysisOverviewCard"))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(AppTheme.border.opacity(0.65), lineWidth: 0.5)
            }
    }

    static func money(_ cents: Int64?) -> String {
        guard let cents else { return "待补资料" }
        let yuan = Decimal(cents) / 100
        let magnitude = yuan < 0 ? -yuan : yuan
        let divisor: Decimal
        let suffix: String
        if magnitude >= 100_000_000 {
            divisor = 100_000_000; suffix = " 亿元"
        } else if magnitude >= 10_000 {
            divisor = 10_000; suffix = " 万元"
        } else {
            return ProfileRules.money(cents, compact: true)
        }
        return (yuan / divisor).formatted(
            .number.locale(Locale(identifier: "zh_CN"))
                .precision(.fractionLength(0...2)).grouping(.never)
        ) + suffix
    }
}

/// 同一预测模块共用卡片背景；只有结论区进入详情，图表保留独立交互。
struct AnalysisSummaryCard<Trend: View, Destination: View>: View {
    let mode: String
    let amount: String
    let notice: String
    let resultIdentifier: String
    private let trend: Trend
    private let destination: Destination

    init(mode: String, amount: String, notice: String, resultIdentifier: String,
         @ViewBuilder trend: () -> Trend, @ViewBuilder destination: () -> Destination) {
        self.mode = mode
        self.amount = amount
        self.notice = notice
        self.resultIdentifier = resultIdentifier
        self.trend = trend()
        self.destination = destination()
    }

    var body: some View {
        OverviewCard(padding: 22, spacing: 16, cornerRadius: 24) {
            NavigationLink { destination } label: {
                OverviewCardHeader(showsDisclosure: true) {
                    HStack(spacing: 10) {
                        Text("生存时长")
                        Text(mode).font(.caption.weight(.medium))
                            .foregroundStyle(AnalysisOverviewStyle.accent)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(AnalysisOverviewStyle.accent.opacity(0.12), in: Capsule())
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("runway.details")
        } content: {
            VStack(alignment: .leading, spacing: 20) {
                NavigationLink { destination } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(amount)
                            .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                            .monospacedDigit().fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(AnalysisOverviewStyle.accent)
                            .accessibilityIdentifier(resultIdentifier)
                        Text(notice).font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("runway.card")
                .accessibilityHint("查看生存时长详情与调整情景")
                trend
            }
        } background: {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color("AnalysisOverviewTop"), Color("AnalysisOverviewBottom")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                // 插画只位于预测结论附近，不延伸到图表坐标或金额区域。
                .overlay(alignment: .top) {
                    AnalysisLandscape().frame(height: 75).padding(.top, 85)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(AnalysisOverviewStyle.accent.opacity(0.13), lineWidth: 0.5)
                }
        }
        .foregroundStyle(AppTheme.primaryText)
    }
}

private struct AnalysisLandscape: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Circle().fill(Color("AnalysisOverviewSun")).frame(width: 28, height: 28)
                    .position(x: w * 0.82, y: h * 0.24)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.55))
                    p.addCurve(to: CGPoint(x: w, y: h * 0.28), control1: CGPoint(x: w * 0.3, y: -h * 0.2), control2: CGPoint(x: w * 0.45, y: h * 1.4))
                    p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
                }.fill(AnalysisOverviewStyle.accent.opacity(0.07))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.8))
                    p.addCurve(to: CGPoint(x: w, y: h * 0.15), control1: CGPoint(x: w * 0.45, y: h * 1.5), control2: CGPoint(x: w * 0.7, y: -h * 0.1))
                    p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
                }.fill(AnalysisOverviewStyle.accent.opacity(0.09))
            }
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct AnalysisContributionCard: View {
    let title: String
    let symbol: String
    let total: Int64?
    /// 仅汇总已比较月份的应缴金额，作为缺口比例的分母。
    let expected: Int64
    let shortfall: Int64?
    let compared: Int
    let missing: Int
    let identifier: String
    let destination: CareerDestination

    var body: some View {
        NavigationLink(value: destination) {
            OverviewCard {
                OverviewCardHeader(
                    icon: symbol,
                    iconColor: AnalysisOverviewStyle.accent,
                    showsDisclosure: true
                ) {
                    Text(title)
                }
            } content: {
                HStack(alignment: .center, spacing: 16) {
                    ContributionGapRing(expected: expected, shortfall: shortfall, compared: compared)
                        .frame(width: 112, height: 112)
                        .frame(maxWidth: .infinity)
                    metrics
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } background: {
                AnalysisOverviewStyle.cardBackground
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .foregroundStyle(AppTheme.primaryText)
        .accessibilityHint("查看\(title)详情")

    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            metricRow("个人累计", amount: total, color: AnalysisOverviewStyle.accent)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("个人累计，\(total.map { ProfileRules.money($0) } ?? "待补资料")")
                .accessibilityIdentifier(identifier + ".total")
            metricRow("疑似少缴", amount: shortfall, color: AppTheme.warning)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("疑似少缴，\(shortfall.map { ProfileRules.money($0) } ?? "待补资料")")
                .accessibilityIdentifier(identifier + ".shortfall")
            Text("已比较 \(compared) 个月" + (missing > 0 ? " · 待补 \(missing) 个月" : ""))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.leading, 14)
                .fixedSize(horizontal: false, vertical: true)
        }
        // 三项指标统一字号；金额增长时允许换行，不通过缩小某一行来塞进列宽。
        .font(.subheadline)
    }

    private func metricRow(_ label: String, amount: Int64?, color: Color) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Circle().fill(color).frame(width: 6, height: 6)
                .accessibilityHidden(true)
            (Text(label + " ").foregroundStyle(AppTheme.secondaryText)
             + Text(AnalysisOverviewStyle.money(amount)).foregroundStyle(AppTheme.primaryText))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

}

/// 缺口比例只使用同一批可比较月份的应缴金额，不以全部累计缴纳金额拼成总额。
private struct ContributionGapRing: View {
    let expected: Int64
    let shortfall: Int64?
    let compared: Int

    private var ratio: Double? {
        guard compared > 0, expected > 0, let shortfall else { return nil }
        return min(max(Double(shortfall) / Double(expected), 0), 1)
    }

    var body: some View {
        ZStack {
            Circle().stroke(AppTheme.secondaryText.opacity(0.12), lineWidth: 9)
            if let ratio {
                Circle().stroke(AnalysisOverviewStyle.accent, lineWidth: 9)
                if ratio > 0 {
                    Circle().trim(from: 0, to: ratio)
                        .stroke(AppTheme.warning, style: StrokeStyle(lineWidth: 9, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
            Text(ratio.map { $0.formatted(.percent.precision(.fractionLength(0...1))) } ?? "—")
                .font(.title3.weight(.semibold)).monospacedDigit()
        }
        .padding(5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ratio.map { "已比较月份疑似缺口比例，\($0.formatted(.percent.precision(.fractionLength(0...1))))" } ?? "资料不足，缺口比例不可用")
    }
}
