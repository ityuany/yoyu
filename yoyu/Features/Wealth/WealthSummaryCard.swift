import SwiftUI

/// An independent black card above the expandable category stack.
struct WealthSummaryCard: View {
    let amount: String
    let debt: String
    let netWorth: String
    let notice: String?
    @State private var showingScope = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private let ink = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let mutedInk = Color(red: 0.70, green: 0.70, blue: 0.68)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("已记录资产").foregroundStyle(mutedInk)
                Spacer()
                Button { showingScope = true } label: {
                    HStack(spacing: 6) {
                        Text("人民币")
                        Image(systemName: "info.circle")
                    }
                    .foregroundStyle(mutedInk)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看资产统计口径")
                .padding(.vertical, -12)
            }
            .font(.caption)

            Text(amount)
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 20))
            layout {
                metric("负债", value: debt)
                metric("净值", value: netWorth)
            }

            if let notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(ink)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.16, green: 0.17, blue: 0.18),
                             Color(red: 0.12, green: 0.13, blue: 0.14),
                             Color(red: 0.07, green: 0.08, blue: 0.09)],
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
                            colors: [Color(red: 0.88, green: 0.91, blue: 0.96).opacity(0.09), .clear],
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
        .alert("资产统计口径", isPresented: $showingScope) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("已记录资产包含现金、已归属股票估值和理财。净值为已记录资产减去已记录负债。\n\n两者均不含房产、未归属股票及预计补偿。预计补偿为税前估算、尚未到账，可在下方裁员补偿卡片查看。\n\n未填写的资产类别暂未计入；未记录负债时暂不显示净值。")
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).foregroundStyle(mutedInk)
            Text(value).monospacedDigit()
        }
        .font(.subheadline)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .combine)
    }
}
