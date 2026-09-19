import SwiftUI

/// Shared visual roles for overview and detail screens.
enum DashboardStyle {
    // Brand color is reserved for the selected bottom tab.
    static let tabSelection = adaptive(light: (128.0 / 255, 0, 32.0 / 255), dark: (230.0 / 255, 160.0 / 255, 180.0 / 255))
    static let accent = Color(uiColor: .label)
    static let background = Color(uiColor: .systemBackground)
    static let cash = adaptive(light: (0.39, 0.56, 0.49), dark: (0.56, 0.74, 0.65))
    static let stock = adaptive(light: (0.33, 0.48, 0.61), dark: (0.54, 0.71, 0.85))
    static let investment = adaptive(light: (0.65, 0.51, 0.34), dark: (0.80, 0.68, 0.49))
    static let compensation = adaptive(light: (0.58, 0.45, 0.65), dark: (0.76, 0.64, 0.83))
    static let pageInset: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let cardSpacing: CGFloat = 16

    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(uiColor: UIColor { traits in
            let color = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: color.0, green: color.1, blue: color.2, alpha: 1)
        })
    }
}

struct DashboardCard: ViewModifier {
    var highlighted = false
    func body(content: Content) -> some View {
        content
            .padding(DashboardStyle.pageInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(DashboardStyle.accent.opacity(highlighted ? 0.12 : 0), lineWidth: 1)
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
            .foregroundStyle(.primary)
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
            .foregroundStyle(.primary)
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

struct DashboardMetric: View {
    let title: String
    let value: String
    let symbol: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.subheadline).foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold)).monospacedDigit()
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dashboardCard()
    }
}

/// Use the same neutral page background for lists and editing forms.
extension View {
    func neutralPageBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(DashboardStyle.background.ignoresSafeArea())
    }
}
