import SwiftUI

/// Keeps the total prominent, with a compact breakdown of known assets.
struct WealthSummaryCard: View {
    let amount: String
    let composition: [(name: String, amount: Double, color: Color)]
    let needsPrice: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    private var compositionTotal: Double { composition.reduce(0) { $0 + $1.amount } }
    private var compositionIsPartial: Bool { composition.count < 4 }
    private var compositionChart: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(composition.indices, id: \.self) { index in
                    Rectangle()
                        .fill(composition[index].color)
                        .frame(width: geometry.size.width * composition[index].amount / compositionTotal)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("总资产").font(.subheadline).foregroundStyle(.secondary)
                DashboardAmount(value: amount)
                Text("人民币 · 含税前预计补偿，不含未归属股票")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            if compositionTotal > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    compositionChart
                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                    layout {
                        ForEach(composition.indices, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Circle().fill(composition[index].color)
                                        .frame(width: 6, height: 6)
                                        .accessibilityHidden(true)
                                    Text(composition[index].name)
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)
                                Text((composition[index].amount / compositionTotal).formatted(.percent.precision(.fractionLength(1))))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }

            if compositionIsPartial {
                Text(needsPrice ? "部分公司股价待补全，合计暂不可用。占比仅含已知资产。" : "待填写的类别暂未计入，占比仅含已知资产。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
    }
}
