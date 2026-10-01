import SwiftUI
import SwiftData

struct CompensationTimelineRow: View {
    let date: String
    let amount: String
    let trend: EmploymentSalaryTrend
    let isFirst: Bool
    let isLast: Bool
    let note: String
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(trend.label)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(trend.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 44, height: 56, alignment: .trailing)
                .padding(.trailing, 8)
            VStack(spacing: 0) {
                Rectangle().fill(isFirst ? Color.clear : trend.color.opacity(0.5))
                    .frame(width: 1, height: 23)
                Circle().fill(trend.color).frame(width: 10, height: 10)
                Rectangle().fill(isLast ? Color.clear : trend.color.opacity(0.5))
                    .frame(width: 1).frame(maxHeight: .infinity)
            }
            .frame(width: 20)
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(date)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(amount)
                            .monospacedDigit()
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(height: 56)
                    if !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 12)
                    } else {
                        Color.clear.frame(height: 16)
                    }
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("查看、修改或删除这条记录")
        }
        .frame(minHeight: 72)
    }
}
