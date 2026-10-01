import SwiftUI

/// 财富与分析摘要卡共用的圆角、反光、描边和阴影。
struct SummaryCardBackground: View {
    var colors: [Color] = [AppTheme.wealthSummaryTop, AppTheme.wealthSummaryMiddle, AppTheme.wealthSummaryBottom]

    var body: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(LinearGradient(
                colors: colors,
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .overlay {
                // A broad, static reflection stays behind the text and inside the card.
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.02), location: 0.12),
                        .init(color: .white.opacity(0.11), location: 0.29),
                        .init(color: .white.opacity(0.035), location: 0.43),
                        .init(color: .clear, location: 0.63)
                    ], startPoint: .topTrailing, endPoint: .bottomLeading))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(RadialGradient(
                        colors: [AppTheme.summaryReflection.opacity(0.09), .clear],
                        center: UnitPoint(x: 0.88, y: -0.15), startRadius: 0, endRadius: 240
                    ))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [.white.opacity(0.48), .white.opacity(0.07), .white.opacity(0.16)],
                        startPoint: .topTrailing, endPoint: .bottomLeading
                    ), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
    }
}
