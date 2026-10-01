import SwiftUI
import SwiftData

struct BonusTimelineView: View {
    let job: Employment
    @Query private var bonuses: [BonusPayment]
    @State private var adding = false
    @State private var editing: BonusPayment?

    private var ordered: [BonusPayment] { BonusRules.payments(bonuses, for: job) }
    private var pendingCount: Int { ordered.filter { $0.year == nil }.count }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    Text("累计年终收入").font(.subheadline).foregroundStyle(.secondary)
                    Text(ordered.isEmpty ? "暂无记录" : ProfileRules.money(BonusRules.total(bonuses, for: job)))
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    Text(ordered.isEmpty ? "仅统计实际收到的税前年终奖" : pendingCount == 0 ? "已确认的税前实发金额" : "\(pendingCount) 笔旧记录待确认年份，暂未计入")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            if ordered.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "gift")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 56, height: 56)
                            .background(Color.secondary.opacity(0.1), in: Circle())
                            .accessibilityHidden(true)
                        Text("还没有年终奖记录")
                            .font(.headline)
                        Text("收到税前年终奖后，点右上角记录。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                } footer: {
                    Text("这家企业没有发放年终奖时，无需添加记录。")
                }
            } else {
                Section("年终奖时间轴") {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, payment in
                        let previous = index + 1 < ordered.count ? ordered[index + 1] : nil
                        CompensationTimelineRow(
                            date: payment.year.map { "\($0) 年 \(payment.month) 月" } ?? "发放年份待确认",
                            amount: ProfileRules.money(payment.amountCents),
                            trend: EmploymentSalaryTrend(current: payment.year == nil ? nil : payment.amountCents,
                                                         previous: previous?.year == nil ? nil : previous?.amountCents),
                            isFirst: index == 0, isLast: index == ordered.count - 1,
                            note: payment.year == nil ? "待补年份" : ""
                        ) { editing = payment }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .neutralPageBackground()
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .navigationTitle("年终奖记录")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("新增年终奖", systemImage: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $adding) { BonusPaymentEditor(job: job, payment: nil) }
        .sheet(item: $editing) { BonusPaymentEditor(job: job, payment: $0) }
    }
}
