import SwiftUI
import SwiftData

struct VestingTimelineSections: View {
    let holdings: [StockHolding]
    let now: Date
    @Binding var selectedDay: Date?
    @Binding var showUnallocated: Bool
    private var schedule: VestingTimeline.Schedule { VestingTimeline.schedule(holdings, on: now) }
    private var years: [Int] { Array(Set(schedule.days.map(\.year))).sorted() }
    private func amount(_ cents: Int64?) -> String { cents.map { ProfileRules.money($0) } ?? "待补全股价或汇率" }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(years, id: \.self) { year in
                TimelineAmountRow(title: "\(String(year)) 年", value: amount(VestingTimeline.sum(schedule.days.filter { $0.year == year }.map(\.yuan))), showsDisclosure: false)
                    .font(.body.weight(.semibold))
                    .modifier(TimelineRowStyle(isYear: true))
                ForEach(schedule.days.filter { $0.year == year }) { day in
                    Button { selectedDay = day.date } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            TimelineAmountRow(title: day.date.formatted(Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "zh_CN"), calendar: ProfileRules.calendar, timeZone: ProfileRules.calendar.timeZone).month(.twoDigits).day(.twoDigits)), value: amount(day.yuan))
                                .font(.subheadline)
                            Text("\(day.id == schedule.days.first?.id ? "下一次 · " : "")\(day.companyCount) 家公司 · \(day.batchCount) 笔授予")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .modifier(TimelineRowStyle(highlighted: day.id == schedule.days.first?.id))
                        .foregroundStyle(.primary).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }.listRowSeparator(.hidden)
        if !schedule.unallocated.isEmpty {
            Button { showUnallocated = true } label: {
                VStack(spacing: 14) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("待安排归属")
                            Text("\(schedule.unallocated.count) 笔授予尚有股数未安排日期").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(amount(VestingTimeline.sum(schedule.unallocated.map(\.yuan)))).font(.subheadline)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }.padding(.vertical, 6).foregroundStyle(.primary).contentShape(Rectangle())
            }.buttonStyle(.plain).listRowSeparator(.hidden)
        }
        if schedule.days.isEmpty {
            Text("暂无已安排的未来归属").foregroundStyle(.secondary).listRowSeparator(.hidden)
        }
        if schedule.invalidCompanies > 0 {
            Text("\(schedule.invalidCompanies) 家公司的授予资料需检查，暂未列入时间线。")
                .font(.caption).foregroundStyle(.secondary).listRowSeparator(.hidden)
        }
        Text("金额按当前股价与汇率折算人民币；全年金额包含该年全部已安排归属。")
            .font(.caption).foregroundStyle(.secondary).padding(.vertical, 8).listRowSeparator(.hidden)
    }

}

/// Reserve the same disclosure space for annual totals and individual installments.
private struct TimelineAmountRow: View {
    let title: String
    let value: String
    var showsDisclosure = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            AdaptiveValueRow(title: title, value: value)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.regular))
                .foregroundStyle(.tertiary)
                .opacity(showsDisclosure ? 1 : 0)
                .accessibilityHidden(true)
        }
    }
}

/// The node aligns with the first text baseline; the rail follows the row's actual height.
private struct TimelineRowStyle: ViewModifier {
    var isYear = false
    var highlighted = false
    private let trackWidth: CGFloat = 10
    private let rowInset: CGFloat = 12

    func body(content: Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: isYear ? "diamond.fill" : "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(highlighted ? DashboardStyle.accent : Color.secondary)
                .frame(width: trackWidth)
                .accessibilityHidden(true)
            content
        }
        .padding(.vertical, rowInset)
        .background(alignment: .leading) {
            Rectangle().fill(Color.secondary.opacity(0.18))
                .frame(width: 1).padding(.leading, trackWidth / 2)
                .accessibilityHidden(true).allowsHitTesting(false)
        }
    }
}

struct VestingSourcesView: View {
    let date: Date?
    @Query private var holdings: [StockHolding]
    @Query private var jobs: [Employment]
    @Environment(CareerClock.self) private var clock
    private var items: [VestingTimeline.Item] {
        let schedule = VestingTimeline.schedule(holdings, on: clock.now)
        return date.map { date in schedule.days.first { $0.date == date }?.items ?? [] } ?? schedule.unallocated
    }
    var body: some View {
        List {
            Section {
                LabeledContent("人民币参考价值", value: VestingTimeline.sum(items.map(\.yuan)).map { ProfileRules.money($0) } ?? "待补全股价或汇率")
            }
            ForEach(items) { item in
                if let holding = StockRules.holdings(holdings).first(where: { $0.id == item.holdingID }) {
                    let name = jobs.first { $0.id == holding.employmentID }?.displayName ?? item.company
                    Section {
                        NavigationLink {
                            EquityGrantDetail(holding: holding, grantID: item.grantID, companyName: name)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(name + " · " + item.grantName).font(.headline)
                                LabeledContent("股数", value: "\(ProfileRules.input(item.shares)) 股")
                                LabeledContent("参考价值", value: item.yuan.map { ProfileRules.money($0) } ?? "待补全股价或汇率")
                            }.font(.subheadline).padding(.vertical, 4)
                        }
                    }
                }
            }
            if items.isEmpty { Text("此处已无待归属记录").foregroundStyle(.secondary) }
        }.neutralPageBackground().navigationTitle(date.map { CareerRules.dateLabel($0) } ?? "待安排归属")
        .toolbar(.visible, for: .navigationBar)
    }
}
