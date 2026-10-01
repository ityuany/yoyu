import SwiftUI

/// A folder-like surface: its header stays visible when the next card overlaps it.
enum WealthCategory: String, CaseIterable, Identifiable {
    case cash, stocks, investment, compensation, debt
    var id: Self { self }
    var title: String {
        switch self {
        case .cash: "灵活资金"
        case .stocks: "股票资产"
        case .investment: "理财产品"
        case .compensation: "裁员补偿"
        case .debt: "债务情况"
        }
    }
    var subtitle: String {
        switch self {
        case .cash: "日常储备"
        case .stocks: "已归属价值"
        case .investment: "当前估算金额"
        case .compensation: "税前估算"
        case .debt: "还款与账单"
        }
    }
    var ink: Color {
        switch self {
        case .cash: AppTheme.WealthCategoryPalette.cashInk
        case .stocks: AppTheme.WealthCategoryPalette.stocksInk
        case .investment: AppTheme.WealthCategoryPalette.investmentInk
        case .compensation: AppTheme.WealthCategoryPalette.compensationInk
        case .debt: AppTheme.WealthCategoryPalette.debtInk
        }
    }
    var fill: LinearGradient {
        switch self {
        case .cash: AppTheme.WealthCategoryPalette.cashFill
        case .stocks: AppTheme.WealthCategoryPalette.stocksFill
        case .investment: AppTheme.WealthCategoryPalette.investmentFill
        case .compensation: AppTheme.WealthCategoryPalette.compensationFill
        case .debt: AppTheme.WealthCategoryPalette.debtFill
        }
    }

}

enum WealthCardGeometry {
    static let minimumHeight: CGFloat = 200
    static let headerHeight: CGFloat = 64
    static let gap: CGFloat = 12

}

struct WealthCategoryCard<Content: View>: View {
    let category: WealthCategory
    let amount: String
    var subtitle: String? = nil
    let isExpanded: Bool
    let toggle: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.title).font(.headline)
                        Text(subtitle ?? category.subtitle).font(.caption).opacity(0.76)
                    }
                    Spacer(minLength: 4)
                    Text(amount)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 22)
                .frame(height: WealthCardGeometry.headerHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(WealthCardNoFeedbackStyle())
            .accessibilityValue(isExpanded ? "已展开" : "已收起")
            .accessibilityHint(isExpanded ? "轻点收起分类" : "轻点展开分类")
            VStack(alignment: .leading, spacing: 16) {
                Rectangle().fill(category.ink.opacity(0.12)).frame(height: 1)
                content
            }
            .font(.subheadline)
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .frame(minHeight: WealthCardGeometry.minimumHeight - WealthCardGeometry.headerHeight,
                   alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            // Keep content visible while cards move; overlapping cards and the
            // stack's clipping conceal it as the selected arrangement closes.
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
        }
        .frame(minHeight: WealthCardGeometry.minimumHeight, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(category.ink)
        .background(category.fill, in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(dark ? Color.white.opacity(0.07) : Color.white.opacity(0.9), lineWidth: 2)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .background {
            // The shadow belongs to the entire surface, so it travels with the card.
            RoundedRectangle(cornerRadius: 28)
                .fill(.black.opacity(dark ? 0.28 : 0.10))
                .shadow(color: .black.opacity(dark ? 0.30 : 0.12), radius: 3, y: -2)
        }
    }
}

/// Keep the header visually unchanged for the entire touch, including release.
/// PlainButtonStyle can still apply the platform's pressed-state appearance.
private struct WealthCardNoFeedbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
