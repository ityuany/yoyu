import SwiftUI

/// A folder-like surface: its header stays visible when the next card overlaps it.
enum WealthCategory: String, CaseIterable, Identifiable {
    case cash, stocks, investment, compensation, debt
    var id: Self { self }
    var title: String {
        switch self {
        case .cash: "现金"
        case .stocks: "股票"
        case .investment: "理财"
        case .compensation: "预计补偿"
        case .debt: "负债"
        }
    }
    var subtitle: String {
        switch self {
        case .cash: "日常储备"
        case .stocks: "已归属价值"
        case .investment: "当前持有"
        case .compensation: "未来资产 · 税前估算"
        case .debt: "还款与账单"
        }
    }
    private var hue: Double {
        switch self {
        case .cash: 0.12
        case .stocks: 0.57
        case .investment: 0.22
        case .compensation: 0.70
        case .debt: 0.04
        }
    }
    var marker: Color { Color(hue: hue, saturation: 0.35, brightness: 0.65) }

    func ink(dark: Bool) -> Color {
        Color(hue: hue, saturation: dark ? 0.24 : 0.55, brightness: dark ? 0.94 : 0.32)
    }
    func fill(dark: Bool) -> LinearGradient {
        LinearGradient(colors: [
            Color(hue: hue, saturation: dark ? 0.30 : 0.09, brightness: dark ? 0.21 : 0.97),
            Color(hue: hue, saturation: dark ? 0.36 : 0.23, brightness: dark ? 0.29 : 0.87)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum WealthCardGeometry {
    static let height: CGFloat = 280
    static let headerHeight: CGFloat = 64
    static let gap: CGFloat = 12
    static let revealDistance = height - headerHeight + gap
}

struct WealthCategoryCard<Content: View>: View {
    let category: WealthCategory
    let amount: String
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
                        Text(category.subtitle).font(.caption).opacity(0.76)
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
                Rectangle().fill(category.ink(dark: dark).opacity(0.12)).frame(height: 1)
                content
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .opacity(isExpanded ? 1 : 0)
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
        }
        .frame(height: WealthCardGeometry.height, alignment: .top)
        .foregroundStyle(category.ink(dark: dark))
        .background(category.fill(dark: dark), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(dark ? Color.white.opacity(0.12) : Color.white.opacity(0.9), lineWidth: 2)
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
