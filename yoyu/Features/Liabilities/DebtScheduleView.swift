import SwiftUI
import SwiftData

struct DebtScheduleView: View {
    @Environment(CareerClock.self) private var clock
    let accounts: [LiabilityAccount]
    @State private var showAll = false
    @State private var expandedMonth: Date?
    private var payments: [DebtPayment] {
        accounts.flatMap { account -> [DebtPayment] in
            guard let snapshot = account.snapshot, let kind = account.kind else { return [] }
            return LiabilityRules.payments(snapshot, kind: kind, on: clock.now).map {
                DebtPayment(id: account.id + $0.id, sourceID: $0.sourceID, name: account.name + " · " + $0.name,
                            date: $0.date, principal: $0.principal, interest: $0.interest, remaining: $0.remaining)
            }
        }.sorted { $0.date < $1.date }
    }
    var body: some View {
        let grouped = Dictionary(grouping: payments, by: { LiabilityRules.month($0.date) })
        let months = grouped.keys.sorted()
        List {
            Section {
                Text("按房贷当前利率与固定分期计算。自动分期默认过了还款日已正常还款；手动分期按已还期数计算。下列金额包含本金和利息／手续费。")
                    .font(.subheadline).foregroundStyle(.secondary)
                if accounts.contains(where: { $0.snapshot == nil || $0.kind == nil || ($0.snapshot != nil && $0.kind != nil && LiabilityRules.error($0.snapshot!, kind: $0.kind!) != nil) }) {
                    Label("部分账户待核对，暂未计入计划", systemImage: "exclamationmark.circle").foregroundStyle(.orange)
                }
                if accounts.contains(where: { $0.kind == .creditCard && $0.snapshot?.fixedInstallmentsOnly != true && $0.snapshot?.billDue == nil }) {
                    Text("有信用卡尚未录入本期账单，当前只展示其已知分期。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if payments.isEmpty {
                ContentUnavailableView("暂无已知还款", systemImage: "calendar", description: Text("补充房贷或固定分期后即可查看。"))
            }
            Section("还款月份") {
                ForEach(Array(showAll ? months : Array(months.prefix(12))), id: \.self) { month in
                    let rows = grouped[month] ?? []
                    DisclosureGroup(isExpanded: Binding(get: { expandedMonth == month }, set: { expandedMonth = $0 ? month : nil })) {
                        ForEach(rows) { row in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(row.name).font(.subheadline.weight(.medium))
                                LabeledContent(CareerRules.dateLabel(row.date), value: ProfileRules.money(row.total))
                                    .font(.subheadline)
                                if row.sourceID != nil {
                                    Text("本金 \(ProfileRules.money(row.principal)) · 利息／费用 \(ProfileRules.money(row.interest))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if let remaining = row.remaining {
                                    Text("本部分预计剩余本金 \(ProfileRules.money(remaining))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if row.date < LiabilityRules.calendar.startOfDay(for: clock.now) {
                                    Text("日期已过 · 请核对是否已还").font(.caption).foregroundStyle(.orange)
                                }
                            }.padding(.vertical, 5)
                        }
                    } label: {
                        LabeledContent(month.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).year().month()), value: LiabilityRules.sum(rows.map(\.total)).map { ProfileRules.money($0) } ?? "金额超出范围")
                    }
                }
            }
            if months.count > 12 {
                Button(showAll ? "收起为前 12 个月" : "显示全部 \(months.count) 个月") { showAll.toggle() }
            }
            Section { Text("房贷本金计入负债，未来利息单独计入预计还款。首末期计息、分币舍入及实际扣款以银行账单为准。")
                .font(.caption).foregroundStyle(.secondary) }
        }.neutralPageBackground()
        .navigationTitle("每月已知还款")
        .task { expandedMonth = months.first }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
