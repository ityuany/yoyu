import SwiftUI

/// Shared visual roles for overview and detail screens.
enum DashboardStyle {
    static let tabSelection = AppTheme.accent
    static let accent = AppTheme.accent
    static let background = AppTheme.pageBackground
    static let cash = AppTheme.chartCash
    static let stock = AppTheme.chartStock
    static let investment = AppTheme.chartInvestment
    static let compensation = AppTheme.chartCompensation
    static let pageInset: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
}

struct DashboardCard: ViewModifier {
    var highlighted = false
    func body(content: Content) -> some View {
        content
            .padding(DashboardStyle.pageInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(highlighted ? AppTheme.highlightedBackground : AppTheme.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(AppTheme.border, lineWidth: 1)
                    }
            }
    }
}

struct DashboardAmount: View {
    let value: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Text(value)
            .font(.system(.largeTitle, design: .rounded).weight(.semibold))
            .foregroundStyle(AppTheme.primaryText)
            .monospacedDigit()
            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.65)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct DashboardSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(AppTheme.primaryText)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// Tab labels identify the main pages; reserve navigation bars for pushed details.
    func dashboardTabRoot(title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
    }

    func dashboardCard(highlighted: Bool = false) -> some View {
        modifier(DashboardCard(highlighted: highlighted))
    }
}

/// Use the same themed page background for lists and editing forms.
extension View {
    func neutralPageBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground.ignoresSafeArea())
    }
}
