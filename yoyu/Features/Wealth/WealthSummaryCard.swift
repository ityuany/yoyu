import SwiftUI

/// A compact overview; category cards provide the detailed balances.
struct WealthSummaryCard: View {
    let amount: String
    let debt: String
    let netWorth: String
    let notice: String?
    @State private var showingScope = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("已记录资产")
                Spacer()
                Button { showingScope = true } label: {
                    HStack(spacing: 6) {
                        Text("人民币")
                        Image(systemName: "info.circle")
                    }
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看资产统计口径")
                .padding(.vertical, -12)
            }
            .font(.caption)

            DashboardAmount(value: amount)

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
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .alert("资产统计口径", isPresented: $showingScope) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("已记录资产包含现金、已归属股票估值和理财。净值为已记录资产减去已记录负债。\n\n两者均不含房产、未归属股票及预计补偿。预计补偿为税前估算、尚未到账，可在下方裁员补偿卡片查看。\n\n未填写的资产类别暂未计入；未记录负债时暂不显示净值。")
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
        .font(.subheadline)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .combine)
    }
}
