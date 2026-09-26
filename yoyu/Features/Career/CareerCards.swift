import SwiftUI

private enum CareerCardLayout {
    static let contentInset: CGFloat = 16
    static let sectionSpacing: CGFloat = 12
}

struct EmploymentSalaryTrend {
    let current: Int64?
    let previous: Int64?

    private var change: Double? {
        guard let current, let previous, previous > 0 else { return nil }
        return (Double(current) / Double(previous) - 1) * 100
    }

    var color: Color {
        guard let current, let previous, previous > 0 else { return .gray }
        if current > previous { return .red }
        if current < previous { return .green }
        return .orange
    }

    var label: String {
        guard let change else { return "—" }
        let value = change.formatted(.number.precision(.fractionLength(0...1)))
        return (change > 0 ? "+" : "") + value + "%"
    }
}

struct EmploymentTimelineRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isOpeningDetail = false

    let job: Employment
    let stages: [SalaryStage]
    let now: Date
    let isFirst: Bool
    let isLast: Bool
    let trend: EmploymentSalaryTrend
    let nextTrend: EmploymentSalaryTrend?
    let onSelect: () -> Void

    private var entrySalary: Int64? {
        guard let start = job.start else { return nil }
        return CareerRules.salary(stages, for: job, on: start)?.salaryCents
    }
    private var latestSalary: Int64? { CareerRules.salary(stages, for: job, on: now)?.salaryCents }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(trend.label)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(trend.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 44, alignment: .trailing)
                .padding(.trailing, 8)
                .frame(height: 54, alignment: .center)
                .accessibilityLabel("入职月薪相较上家公司最终月薪\(trend.label)")
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : trend.color.opacity(0.65))
                    .frame(width: 1, height: 22)
                Circle()
                    .fill(trend.color)
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(LinearGradient(
                        colors: isLast
                            ? [trend.color.opacity(0.65), trend.color.opacity(0)]
                            : [trend.color.opacity(0.65), (nextTrend?.color ?? .gray).opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(dateLabel(job.start)) — \(job.end.map { dateLabel($0) } ?? "至今")")
                    .font(.headline)
                    .padding(.top, 16)
                Button {
                    guard !isOpeningDetail else { return }
                    isOpeningDetail = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(150))
                        onSelect()
                        isOpeningDetail = false
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(job.displayName)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("在职")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(tenureLabel)
                                .font(.subheadline.weight(.semibold))
                            Text("月薪变化")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(salaryLabel(entrySalary)) — \(salaryLabel(latestSalary))")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .accessibilityLabel("入职月薪\(salaryLabel(entrySalary))，最终月薪\(salaryLabel(latestSalary))")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 18)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 20)
                    .background(bookColor, in: bookShape)
                    .overlay {
                        bookShape.strokeBorder(Color.primary.opacity(colorScheme == .light ? 0.11 : 0.08), lineWidth: 1)
                    }
                    .contentShape(bookShape)
                }
                .buttonStyle(EmploymentCardPressStyle(isOpeningDetail: isOpeningDetail))
                .shadow(color: .black.opacity(colorScheme == .light ? 0.06 : 0), radius: 8, y: 3)
                .accessibilityIdentifier("employment.timeline.\(job.id)")
                .accessibilityHint("打开\(job.displayName)的任职档案")
                .padding(.top, 13)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
            .padding(.bottom, isLast ? 28 : 0)
        }
        .padding(.horizontal, 16)
        .foregroundStyle(.primary)
    }

    private var bookShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10,
                               bottomTrailingRadius: 32, topTrailingRadius: 32)
    }

    private var bookColor: Color {
        colorScheme == .light
            ? Color(red: 247 / 255, green: 245 / 255, blue: 239 / 255)
            : Color(red: 37 / 255, green: 35 / 255, blue: 31 / 255)
    }

    private var tenureLabel: String {
        let calendar = ProfileRules.calendar
        guard let start = job.start,
              let days = CareerRules.tenureDays(for: job, on: now),
              let end = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: start)) else {
            return "时长待补全"
        }
        let parts = calendar.dateComponents([.year, .month], from: calendar.startOfDay(for: start), to: end)
        let years = parts.year ?? 0
        let months = parts.month ?? 0
        if years > 0 { return "\(years) 年" + (months > 0 ? " \(months) 个月" : "") }
        if months > 0 { return "\(months) 个月" }
        return "\(days) 天"
    }

    private func salaryLabel(_ value: Int64?) -> String {
        value.map { ProfileRules.money($0, compact: true) } ?? "待补全"
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date else { return "日期待补全" }
        let parts = ProfileRules.calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d.%02d", parts.year!, parts.month!)
    }
}

private struct EmploymentCardPressStyle: ButtonStyle {
    let isOpeningDetail: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed || isOpeningDetail ? 0.975 : 1)
            .opacity(configuration.isPressed || isOpeningDetail ? 0.78 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed || isOpeningDetail)
    }
}

struct SalaryStageCard: View {
    let stage: SalaryStage
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: CareerCardLayout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(effectiveDateTitle).fontWeight(.medium).fixedSize()
                            Spacer(minLength: 8)
                            salaryTitle.fixedSize()
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(effectiveDateTitle).fontWeight(.medium)
                            salaryTitle
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.body)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                if let date = stage.effectiveDate, date > now {
                    Text("待生效").font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                valueRow("年终奖", value: ProfileRules.money(stage.bonusCents))
            }
        }
        .padding(CareerCardLayout.contentInset)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var effectiveDateTitle: String {
        guard let date = stage.effectiveDate else { return "生效月份待补充" }
        return CareerRules.monthLabel(date)
    }

    private var salaryTitle: some View {
        let amount = ProfileRules.money(stage.salaryCents, compact: true)
        return Text(amount)
            .fontWeight(.regular)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .accessibilityLabel("税前月薪 \(amount)")
    }

    private func valueRow(_ title: String, value: String) -> some View {
        AdaptiveValueRow(title: title, value: value, valueColor: .secondary)
            .font(.subheadline).foregroundStyle(.secondary)
    }
}
