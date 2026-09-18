import SwiftUI

/// These are full-content cards, not menu rows. Their list hosts use zero insets;
/// all interior spacing is owned here, while List owns the distance between cards.
private enum CareerCardLayout {
    static let contentInset: CGFloat = 16
    static let sectionSpacing: CGFloat = 12
}

struct EmploymentOverviewCard: View {
    let job: Employment
    let stages: [SalaryStage]
    let now: Date

    private var isCurrent: Bool { job.isCurrent(on: now) }
    private var salary: Int64? { CareerRules.salary(stages, for: job, on: now)?.salaryCents }
    private var income: Int64? { CareerRules.estimatedSalaryCents(stages, for: job, on: now) }

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(job.displayName).font(.headline)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                Text("\(dateLabel(job.start))—\(job.end.map { dateLabel($0) } ?? "至今") · \(tenureLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            layout {
                metric(isCurrent ? "当前月薪 · 税前" : "离职月薪 · 税前",
                       value: salary.map { ProfileRules.money($0, compact: true) } ?? "待补全")
                metric("累计收入 · 税前估算", value: income.map {
                    (Decimal($0) / 100).formatted(.currency(code: "CNY")
                        .locale(Locale(identifier: "zh_CN")).precision(.fractionLength(0)))
                } ?? "待补全")
            }
        }
        .padding(CareerCardLayout.contentInset)
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
        .accessibilityHint("查看任职详情和薪资阶段")
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tenureLabel: String {
        let calendar = ProfileRules.calendar
        guard let start = job.start,
              let days = CareerRules.tenureDays(for: job, on: now),
              let end = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: start)) else {
            return "在职时长待补全"
        }
        let parts = calendar.dateComponents([.year, .month], from: calendar.startOfDay(for: start), to: end)
        let years = parts.year ?? 0
        let months = parts.month ?? 0
        if years > 0 { return "在职 \(years) 年" + (months > 0 ? " \(months) 个月" : "") }
        if months > 0 { return "在职 \(months) 个月" }
        return "在职 \(days) 天"
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date else { return "日期待补全" }
        let parts = ProfileRules.calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d.%02d", parts.year!, parts.month!)
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
                contributionRow("养老金", rate: stage.pensionBasisPoints)
                contributionRow("公积金", rate: stage.housingBasisPoints)
                valueRow("年终奖", value: ProfileRules.money(stage.bonusCents))
            }
        }
        .padding(CareerCardLayout.contentInset)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var effectiveDateTitle: String {
        guard let date = stage.effectiveDate else { return "生效日期待补充" }
        let parts = ProfileRules.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d年%02d月%02d日", parts.year!, parts.month!, parts.day!)
    }

    private var salaryTitle: some View {
        let amount = ProfileRules.money(stage.salaryCents, compact: true)
        return Text(amount)
            .fontWeight(.regular)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .accessibilityLabel("税前月薪 \(amount)")
    }

    private func monthlyMoney(_ amount: Int64?) -> String {
        ProfileRules.money(amount)
    }

    private func contributionRow(_ title: String, rate: Int64?) -> some View {
        let label = rate.map { "\(title)（\(ProfileRules.input($0))%）" } ?? title
        let amount = ProfileRules.monthlyContribution(salaryCents: stage.salaryCents, rateBasisPoints: rate)
        return valueRow(label, value: monthlyMoney(amount))
    }

    private func valueRow(_ title: String, value: String) -> some View {
        AdaptiveValueRow(title: title, value: value, valueColor: .secondary)
            .font(.subheadline).foregroundStyle(.secondary)
    }
}
