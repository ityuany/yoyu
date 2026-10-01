import SwiftUI
import SwiftData

struct LiabilityDetailView: View {
    @Environment(CareerClock.self) private var clock
    let accountID: String
    @Query private var records: [LiabilityAccount]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var deleting = false
    @State private var confirming = false
    @State private var errorMessage: String?
    private var account: LiabilityAccount? { LiabilityRules.accounts(records).first { $0.id == accountID } }

    var body: some View {
        Group {
            if let account, let kind = account.kind, let snapshot = account.snapshot {
                let schedule = LiabilityRules.payments(snapshot, kind: kind, on: clock.now)
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LiabilityRules.hasAutomaticProgress(snapshot) ? "预计剩余本金" : kind == .mortgage || snapshot.fixedInstallmentsOnly == true ? "已确认剩余本金" : "已确认总欠款").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                            DashboardAmount(value: LiabilityRules.balance(snapshot, kind: kind, on: clock.now).map { ProfileRules.money($0) } ?? "待核对")
                            Text(LiabilityRules.hasAutomaticProgress(snapshot) ? "截至 \(CareerRules.dateLabel(clock.now)) · 按正常每月还款推算" : "余额确认于 \(CareerRules.dateLabel(snapshot.balanceDate))")
                                .font(.caption).foregroundStyle(AppTheme.secondaryText)
                        }.padding(.vertical, 8)
                        if kind == .mortgage, let last = schedule.last {
                            LabeledContent("预计结清", value: CareerRules.dateLabel(last.date))
                            LabeledContent("预计利息", value: LiabilityRules.sum(schedule.map(\.interest)).map { ProfileRules.money($0) } ?? "超出范围")
                        }
                        if let error = LiabilityRules.error(snapshot, kind: kind) {
                            Label(error, systemImage: "exclamationmark.circle").foregroundStyle(AppTheme.warning)
                        }
                    }.listRowBackground(AppTheme.cardBackground)
                    if kind == .mortgage { mortgageDetails(snapshot) } else { cardDetails(snapshot) }
                    Section {
                        NavigationLink { DebtScheduleView(accounts: [account]) } label: {
                            Label("查看逐月还款计划", systemImage: "calendar")
                        }
                        if kind != .mortgage {
                            Button(snapshot.fixedInstallmentsOnly == true ? "编辑分期与还款进度" : "校准余额与计划") { editing = true }
                        }
                        if LiabilityRules.confirmed(snapshot, kind: kind, on: clock.now) != nil {
                            Button(kind == .mortgage || snapshot.fixedInstallmentsOnly == true ? "登记一期还款" : "确认本期账单已还清") { confirming = true }
                        }
                    } footer: {
                        Text(LiabilityRules.hasAutomaticProgress(snapshot) ? "自动推算不代表银行实际扣款。如有延期或未扣款，请编辑对应分期，关闭自动推算并调整已还期数。" : kind == .mortgage ? "仅在银行确已扣款后确认。确认会更新负债余额，不会自动扣减现金资产。部分还款、提前还款或利率调整，请点击右上角“编辑”，按银行结果更新。" : "仅在银行确已扣款后确认。确认会更新负债余额，不会自动扣减现金资产。部分还款、提前还款或利率调整，请使用校准入口按银行结果更新。")
                    }.listRowBackground(AppTheme.cardBackground)
                    if !snapshot.note.isEmpty { Section("备注") { Text(snapshot.note) }.listRowBackground(AppTheme.cardBackground) }
                    Section { Button("删除此账户", role: .destructive) { deleting = true } }.listRowBackground(AppTheme.cardBackground)
                }.neutralPageBackground()
                .navigationTitle(account.name)
                .toolbar {
                    if kind == .mortgage {
                        ToolbarItem(placement: .primaryAction) {
                            Button("编辑") { editing = true }
                        }
                    }
                }
                .sheet(isPresented: $editing) { LiabilityEditor(kind: kind, account: account) }
                .alert("确认银行已完成还款？", isPresented: $confirming) {
                    Button("取消", role: .cancel) {}
                    Button("确认已还") { confirm(account, snapshot: snapshot, kind: kind) }
                } message: {
                    Text(confirmationText(snapshot, kind: kind))
                }
                .alert("删除\(account.name)？", isPresented: $deleting) {
                    Button("取消", role: .cancel) {}
                    Button("删除", role: .destructive) {
                        for record in records where record.id == account.id { context.delete(record) }
                        do { try context.save(); dismiss() } catch { context.rollback(); errorMessage = error.localizedDescription }
                    }
                } message: { Text("将删除此账户及分期计划。") }
            } else {
                ContentUnavailableView("记录暂不可用", systemImage: "exclamationmark.circle", description: Text("请返回负债列表，等待同步完成后重试。"))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .saveErrorAlert($errorMessage)
    }

    private func mortgageDetails(_ snapshot: LiabilitySnapshot) -> some View {
        ForEach(snapshot.mortgages) { part in
            let schedule = LiabilityRules.mortgage(part)
            Section(part.name) {
                LabeledContent("剩余本金", value: ProfileRules.money(part.principal))
                LabeledContent("预计利息", value: LiabilityRules.sum(schedule.map(\.interest)).map { ProfileRules.money($0) } ?? "超出范围")
                LabeledContent("执行年利率", value: part.annualPercent.formatted(.number.precision(.fractionLength(0...4))) + "%")
                LabeledContent("还款方式", value: part.method.title)
                if let next = schedule.first {
                    LabeledContent("下期预计还款", value: ProfileRules.money(next.total))
                    LabeledContent("下次还款日", value: CareerRules.dateLabel(next.date))
                    LabeledContent("剩余期数", value: "\(part.months) 期")
                } else { Text("已结清").foregroundStyle(AppTheme.secondaryText) }
            }.listRowBackground(AppTheme.cardBackground)
        }
    }
    @ViewBuilder private func cardDetails(_ snapshot: LiabilitySnapshot) -> some View {
        if snapshot.fixedInstallmentsOnly == true {
            Section {
                LabeledContent("后续利息／手续费", value: ProfileRules.money(LiabilityRules.sum(LiabilityRules.payments(snapshot, kind: .creditCard, on: clock.now).map(\.interest))))
                LabeledContent("剩余应还（含息）", value: ProfileRules.money(LiabilityRules.sum(LiabilityRules.payments(snapshot, kind: .creditCard, on: clock.now).map(\.total))))
                if let day = snapshot.cardRepaymentDay {
                    LabeledContent("每月还款日", value: "每月 \(day) 日")
                }
                Text("只统计固定分期，未来利息不计入剩余本金；剩余应还包含本金和利息／手续费。")
                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
            }.listRowBackground(AppTheme.cardBackground)
            ForEach(snapshot.installments) { plan in
                Section(plan.name) {
                    LabeledContent("分期总额", value: ProfileRules.money(plan.principal))
                    LabeledContent(plan.terms?.automatic == true ? "预计已还" : "手动已还", value: "\(LiabilityRules.paidCount(plan, on: clock.now)) / \(plan.months) 期")
                    if LiabilityRules.paidCount(plan, on: clock.now) < plan.months {
                        LabeledContent("当前待还", value: "第 \(LiabilityRules.paidCount(plan, on: clock.now) + 1) 期")
                    }
                    if let terms = plan.terms {
                        LabeledContent(terms.mode.title, value: terms.rate.formatted(.number.precision(.fractionLength(0...4))) + "%")
                    }
                    LabeledContent("总利息／手续费", value: ProfileRules.money(LiabilityRules.sum(LiabilityRules.fullInstallments(plan).map(\.interest))))
                    LabeledContent("剩余本金", value: ProfileRules.money(LiabilityRules.sum(LiabilityRules.installments(plan, on: clock.now).map(\.principal))))
                    if let next = LiabilityRules.installments(plan, on: clock.now).first {
                        LabeledContent("下期应还", value: ProfileRules.money(next.total))
                        LabeledContent("下次还款日", value: CareerRules.dateLabel(next.date))
                    } else { Text(plan.terms?.automatic == true ? "预计已结清" : "已结清").foregroundStyle(AppTheme.secondaryText) }
                }.listRowBackground(AppTheme.cardBackground)
            }
        } else { legacyCardDetails(snapshot) }
    }
    private func legacyCardDetails(_ snapshot: LiabilitySnapshot) -> some View {
        Group {
            Section {
                LabeledContent("本期剩余应还", value: snapshot.billDue.map { ProfileRules.money($0) } ?? "待录入账单")
                LabeledContent("本期还款日", value: CareerRules.dateLabel(snapshot.billDate))
                LabeledContent("其中分期未还本金", value: LiabilityRules.sum(snapshot.installments.map(\.principal)).map { ProfileRules.money($0) } ?? "待核对")
                LabeledContent("后续分期费用（预计）", value: LiabilityRules.sum(LiabilityRules.payments(snapshot, kind: .creditCard, on: clock.now).map(\.interest)).map { ProfileRules.money($0) } ?? "超出范围")
            } footer: { Text("分期本金已包含在总欠款内，不重复相加。未来消费与未入账费用不在当前总欠款中。") }.listRowBackground(AppTheme.cardBackground)
            if !snapshot.installments.isEmpty {
                Section("分期计划") {
                    ForEach(snapshot.installments) { plan in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(plan.name).font(.headline)
                                Spacer()
                                Text("剩余 \(plan.months) 期").font(.caption).foregroundStyle(AppTheme.secondaryText)
                            }
                            Text("未还本金 \(ProfileRules.money(plan.principal))")
                            if let next = LiabilityRules.installments(plan, on: clock.now).first {
                                Text("\(CareerRules.dateLabel(next.date)) · 下期 \(ProfileRules.money(next.total))，含费用 \(ProfileRules.money(next.interest))")
                                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
                            }
                        }.padding(.vertical, 4)
                    }
                }.listRowBackground(AppTheme.cardBackground)
            }
        }
    }
    private func confirmationText(_ snapshot: LiabilitySnapshot, kind: LiabilityKind) -> String {
        if kind == .creditCard && snapshot.fixedInstallmentsOnly != true {
            return "确认本期剩余应还 \(ProfileRules.money(snapshot.billDue)) 已还清？将更新欠款与分期，下一期账单需重新录入。"
        }
        let rows = kind == .creditCard && snapshot.fixedInstallmentsOnly == true
            ? snapshot.installments.filter { $0.terms?.automatic != true }.flatMap { LiabilityRules.installments($0, on: clock.now) }.sorted { $0.date < $1.date }
            : LiabilityRules.payments(snapshot, kind: kind, on: clock.now)
        guard let date = rows.first?.date else { return "请先核对还款计划。" }
        let amount = LiabilityRules.sum(rows.filter { $0.date == date }.map(\.total))
        return "确认 \(CareerRules.dateLabel(date)) 的 \(ProfileRules.money(amount)) 已还？将减少对应本金，不自动扣减现金。"
    }

    private func confirm(_ account: LiabilityAccount, snapshot: LiabilitySnapshot, kind: LiabilityKind) {
        guard let next = LiabilityRules.confirmed(snapshot, kind: kind, on: clock.now) else { return }
        do { try LiabilityStore.save(next, name: account.name, kind: kind, account: account, context: context) }
        catch { errorMessage = error.localizedDescription }
    }
}
