import SwiftUI

/// Semantic color roles. Light/dark sRGB values live in Assets.xcassets/Theme.
/// Data series stay separate from status colors even when they share a hue.
enum AppTheme {
    static let pageBackground = Color("PageBackground")
    static let cardBackground = Color("CardBackground")
    static let highlightedBackground = Color("HighlightedBackground")
    static let insetBackground = Color("InsetBackground")
    static let border = Color("Border")
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")
    static let accent = Color("Accent")
    static let onAccent = Color("OnAccent")
    static let success = Color("Success")
    static let warning = Color("Warning")
    static let error = Color("Error")
    static let chartCash = Color("ChartCash")
    static let chartStock = Color("ChartStock")
    static let chartInvestment = Color("ChartInvestment")
    static let chartCompensation = Color("ChartCompensation")
    static let chartDebt = Color("ChartDebt")

    /// Existing folder-card colors retain their category identity in both modes.
    enum WealthCategoryPalette {
        static let cashInk = Color("WealthCashInk")
        static let cashFill = LinearGradient(
            colors: [Color("WealthCashTop"), Color("WealthCashBottom")],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        static let stocksInk = Color("WealthStocksInk")
        static let stocksFill = LinearGradient(
            colors: [Color("WealthStocksTop"), Color("WealthStocksBottom")],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        static let investmentInk = Color("WealthInvestmentInk")
        static let investmentFill = LinearGradient(
            colors: [Color("WealthInvestmentTop"), Color("WealthInvestmentBottom")],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        static let compensationInk = Color("WealthCompensationInk")
        static let compensationFill = LinearGradient(
            colors: [Color("WealthCompensationTop"), Color("WealthCompensationBottom")],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        static let debtInk = Color("WealthDebtInk")
        static let debtFill = LinearGradient(
            colors: [Color("WealthDebtTop"), Color("WealthDebtBottom")],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let careerBookBackground = Color("CareerBookBackground")
    static let mortgageInk = Color("MortgageInk")
    static let mortgageAccent = Color("MortgageAccent")
    static let mortgagePaper = Color("MortgagePaper")
    // The independent black material card intentionally keeps its own palette.
    static let wealthSummaryInk = Color("WealthSummaryInk")
    static let wealthSummaryMutedInk = Color("WealthSummaryMutedInk")
    static let wealthSummaryTop = Color("WealthSummaryTop")
    static let wealthSummaryMiddle = Color("WealthSummaryMiddle")
    static let wealthSummaryBottom = Color("WealthSummaryBottom")
    static let summaryReflection = Color("SummaryReflection")

    /// Seasonal colors belong to the Today scene, independently of the app theme.
    enum TodayPalette {
        case work, makeup, rest, springFestival, midAutumn, greenHoliday, coastalHoliday

        init(mood: TodayMood) {
            switch mood.kind {
            case .work: self = .work
            case .makeup: self = .makeup
            case .weekend, .rest: self = .rest
            case .holiday:
                switch mood.holidayName {
                case "春节": self = .springFestival
                case "中秋节": self = .midAutumn
                case "清明节", "端午节": self = .greenHoliday
                default: self = .coastalHoliday
                }
            }
        }

        var ink: Color {
            switch self {
            case .work: Color("TodayWorkInk")
            case .makeup: Color("TodayMakeupInk")
            case .rest: Color("TodayRestInk")
            case .springFestival: Color("TodaySpringFestivalInk")
            case .midAutumn: Color("TodayMidAutumnInk")
            case .greenHoliday: Color("TodayGreenHolidayInk")
            case .coastalHoliday: Color("TodayCoastalHolidayInk")
            }
        }
        var fill: LinearGradient {
            let colors: [Color]
            switch self {
            case .work: colors = [Color("TodayWorkTop"), Color("TodayWorkBottom")]
            case .makeup: colors = [Color("TodayMakeupTop"), Color("TodayMakeupBottom")]
            case .rest: colors = [Color("TodayRestTop"), Color("TodayRestBottom")]
            case .springFestival: colors = [Color("TodaySpringFestivalTop"), Color("TodaySpringFestivalBottom")]
            case .midAutumn: colors = [Color("TodayMidAutumnTop"), Color("TodayMidAutumnBottom")]
            case .greenHoliday: colors = [Color("TodayGreenHolidayTop"), Color("TodayGreenHolidayBottom")]
            case .coastalHoliday: colors = [Color("TodayCoastalHolidayTop"), Color("TodayCoastalHolidayBottom")]
            }
            return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

}

extension View {
    /// Apply at production and isolated test roots so presented views inherit the theme.
    func appTheme() -> some View {
        tint(AppTheme.accent)
            .foregroundStyle(AppTheme.primaryText)
            .background(AppTheme.pageBackground.ignoresSafeArea())
    }
}
