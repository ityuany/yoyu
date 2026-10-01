import SwiftUI

struct EquityFourPeriodGenerator: View {
    let quantity: String
    let grantDate: Date
    @Binding var entries: [EquityInstallmentDraft]
    @State private var first = Date()
    @State private var months = 12

    private var plan: [EquityInstallment] {
        guard let total = ProfileRules.scaledValue(quantity) else { return [] }
        return EquityRules.splitFour(first: first, months: months, total: total)
    }

    var body: some View {
        DatePicker("首次归属", selection: $first, in: grantDate..., displayedComponents: .date)
        Picker("归属间隔", selection: $months) {
            Text("每月").tag(1)
            Text("每季度").tag(3)
            Text("每年").tag(12)
        }
        Text("按总量的 25% 拆分，前三期向下取整，余数放入第 4 期。")
            .font(.caption).foregroundStyle(AppTheme.secondaryText)
        if plan.isEmpty {
            Text("请输入至少 4 股的整数总量；零碎股可使用逐笔添加。")
                .font(.caption).foregroundStyle(AppTheme.secondaryText)
        } else {
            ForEach(Array(plan.enumerated()), id: \.offset) { index, entry in
                LabeledContent("第 \(index + 1) 期", value: "\(ProfileRules.input(entry.shares)) 股")
            }
        }
        Button(entries.isEmpty ? "生成 4 期归属" : "按总量重新生成 4 期（替换列表）") {
            entries = plan.map { EquityInstallmentDraft(date: $0.date, quantity: ProfileRules.input($0.shares)) }
        }
        .disabled(plan.isEmpty)
        .onAppear { first = max(first, grantDate) }
        .onChange(of: grantDate) { _, value in first = max(first, value) }
    }
}

