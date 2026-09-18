import SwiftUI
import SwiftData

struct LiabilityOverviewView: View {
    @Environment(CareerClock.self) private var clock
    var filter: LiabilityKind? = nil
    var isExample = false
    @Query private var records: [LiabilityAccount]
    @State private var adding: LiabilityKind?
    init(filter: LiabilityKind? = nil, isExample: Bool = false) {
        self.filter = filter
        self.isExample = isExample
        #if DEBUG
        if isExample && ProcessInfo.processInfo.arguments.contains("--debt-edit-card") {
            _adding = State(initialValue: .creditCard)
        } else if isExample && ProcessInfo.processInfo.arguments.contains("--debt-edit-mortgage") {
            _adding = State(initialValue: .mortgage)
        }
        #endif
    }

    private var accounts: [LiabilityAccount] {
        LiabilityRules.accounts(records).filter { filter == nil || $0.kind == filter }
    }
    var body: some View {
        List {
            if isExample {
                Section { Label("示例账本 · 不写入你的真实记录", systemImage: "sparkles").font(.subheadline) }
            }
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("当前负债").font(.subheadline).foregroundStyle(.secondary)
                    DashboardAmount(value: accounts.isEmpty ? "待录入" : LiabilityRules.total(accounts, on: clock.now).map { ProfileRules.money($0) } ?? "待核对")
                    Text("房贷按已确认余额；自动分期按日期预计正常还款，手动分期按已还期数。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
                NavigationLink { DebtScheduleView(accounts: accounts) } label: {
                    Label("每月已知还款", systemImage: "calendar")
                }.disabled(accounts.isEmpty)
            }
            ForEach(LiabilityKind.allCases.filter { filter == nil || $0 == filter }) { kind in
                Section(kind.title) {
                    let group = accounts.filter { $0.kind == kind }
                    ForEach(group) { account in
                        NavigationLink { LiabilityDetailView(accountID: account.id) } label: {
                            HStack {
                                Label(account.name, systemImage: kind.icon)
                                Spacer()
                                Text(account.snapshot.flatMap { LiabilityRules.balance($0, kind: kind, on: clock.now) }.map { ProfileRules.money($0, compact: true) } ?? "待核对")
                                    .foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                    }
                    Button { adding = kind } label: { Label("添加\(kind.title)", systemImage: "plus") }
                }
            }
            if !isExample && accounts.isEmpty {
                Section {
                    NavigationLink { LiabilityExampleView() } label: {
                        Label("先看组合贷与分期示例", systemImage: "eye")
                    }
                }
            }
        }.neutralPageBackground()
        .navigationTitle(filter?.title ?? "负债管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $adding) { LiabilityEditor(kind: $0) }
    }
}

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
                            Text(LiabilityRules.hasAutomaticProgress(snapshot) ? "预计剩余本金" : kind == .mortgage || snapshot.fixedInstallmentsOnly == true ? "已确认剩余本金" : "已确认总欠款").font(.subheadline).foregroundStyle(.secondary)
                            DashboardAmount(value: LiabilityRules.balance(snapshot, kind: kind, on: clock.now).map { ProfileRules.money($0) } ?? "待核对")
                            Text(LiabilityRules.hasAutomaticProgress(snapshot) ? "截至 \(CareerRules.dateLabel(clock.now)) · 按正常每月还款推算" : "余额确认于 \(CareerRules.dateLabel(snapshot.balanceDate))")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                        if kind == .mortgage, let last = schedule.last {
                            LabeledContent("预计结清", value: CareerRules.dateLabel(last.date))
                            LabeledContent("后续预计利息", value: LiabilityRules.sum(schedule.map(\.interest)).map { ProfileRules.money($0) } ?? "超出范围")
                        }
                        if let error = LiabilityRules.error(snapshot, kind: kind) {
                            Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.orange)
                        }
                    }
                    if kind == .mortgage { mortgageDetails(snapshot) } else { cardDetails(snapshot) }
                    Section {
                        NavigationLink { DebtScheduleView(accounts: [account]) } label: {
                            Label("查看逐月还款计划", systemImage: "calendar")
                        }
                        Button(kind == .creditCard && snapshot.fixedInstallmentsOnly == true ? "编辑分期与还款进度" : "校准余额与计划") { editing = true }
                        if LiabilityRules.confirmed(snapshot, kind: kind, on: clock.now) != nil {
                            Button(kind == .mortgage || snapshot.fixedInstallmentsOnly == true ? "登记一期还款" : "确认本期账单已还清") { confirming = true }
                        }
                    } footer: {
                        Text(LiabilityRules.hasAutomaticProgress(snapshot) ? "自动推算不代表银行实际扣款。如有延期或未扣款，请编辑对应分期，关闭自动推算并调整已还期数。" : "仅在银行确已扣款后确认。确认会更新负债余额并保留原记录，不会自动扣减现金资产。部分还款、提前还款或利率调整，请使用校准入口按银行结果更新。")
                    }
                    if !snapshot.note.isEmpty { Section("备注") { Text(snapshot.note) } }
                    if let history = account.history, !history.isEmpty {
                        Section("校准历史") {
                            ForEach(history.reversed()) { revision in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(revision.reason).font(.subheadline)
                                    Text("\(CareerRules.dateLabel(revision.date)) · 调整前余额 \(LiabilityRules.balance(revision.snapshot, kind: kind, on: revision.date).map { ProfileRules.money($0) } ?? "未知")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Section { Button("删除此账户", role: .destructive) { deleting = true } }
                }.neutralPageBackground()
                .navigationTitle(account.name)
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
                } message: { Text("将删除此账户、分期计划及校准历史。") }
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
            Section(part.name) {
                LabeledContent("剩余本金", value: ProfileRules.money(part.principal))
                LabeledContent("执行年利率", value: part.annualPercent.formatted(.number.precision(.fractionLength(0...4))) + "%")
                LabeledContent("还款方式", value: part.method.title)
                if let next = LiabilityRules.mortgage(part).first {
                    LabeledContent("下期预计还款", value: ProfileRules.money(next.total))
                    LabeledContent("下次还款日", value: CareerRules.dateLabel(next.date))
                    LabeledContent("剩余期数", value: "\(part.months) 期")
                } else { Text("已结清").foregroundStyle(.secondary) }
            }
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
                    .font(.caption).foregroundStyle(.secondary)
            }
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
                    } else { Text(plan.terms?.automatic == true ? "预计已结清" : "已结清").foregroundStyle(.secondary) }
                }
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
            } footer: { Text("分期本金已包含在总欠款内，不重复相加。未来消费与未入账费用不在当前总欠款中。") }
            if !snapshot.installments.isEmpty {
                Section("分期计划") {
                    ForEach(snapshot.installments) { plan in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(plan.name).font(.headline)
                                Spacer()
                                Text("剩余 \(plan.months) 期").font(.caption).foregroundStyle(.secondary)
                            }
                            Text("未还本金 \(ProfileRules.money(plan.principal))")
                            if let next = LiabilityRules.installments(plan, on: clock.now).first {
                                Text("\(CareerRules.dateLabel(next.date)) · 下期 \(ProfileRules.money(next.total))，含费用 \(ProfileRules.money(next.interest))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4)
                    }
                }
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
        do { try LiabilityStore.save(next, name: account.name, kind: kind, account: account, reason: "确认还款", context: context) }
        catch { errorMessage = error.localizedDescription }
    }
}

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

struct LiabilityExampleView: View {
    @State private var container: ModelContainer?
    @State private var errorMessage: String?
    var body: some View {
        Group {
            if let container { exampleContent(container).modelContainer(container) }
            else if let errorMessage { ContentUnavailableView("示例暂不可用", systemImage: "exclamationmark.circle", description: Text(errorMessage)) }
            else { ProgressView("准备示例").task { prepare() } }
        }
    }
    @ViewBuilder private func exampleContent(_ container: ModelContainer) -> some View {
        #if DEBUG
        let accounts = (try? container.mainContext.fetch(FetchDescriptor<LiabilityAccount>())) ?? []
        if ProcessInfo.processInfo.arguments.contains("--debt-plan") {
            DebtScheduleView(accounts: accounts)
        } else if ProcessInfo.processInfo.arguments.contains("--debt-card"), let account = accounts.first(where: { $0.kind == .creditCard }) {
            LiabilityDetailView(accountID: account.id)
        } else if ProcessInfo.processInfo.arguments.contains("--debt-mortgage"), let account = accounts.first(where: { $0.kind == .mortgage }) {
            LiabilityDetailView(accountID: account.id)
        } else {
            LiabilityOverviewView(isExample: true)
        }
        #else
        LiabilityOverviewView(isExample: true)
        #endif
    }

    @MainActor private func prepare() {
        do {
            let container = try ModelContainer(for: LiabilityAccount.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
            let date = LiabilityRules.calendar.startOfDay(for: Date())
            let next = LiabilityRules.date(date, offset: 1, day: 15)
            let mortgage = LiabilitySnapshot(balanceDate: date, mortgages: [
                .init(name: "公积金贷款", principal: 600_000_00, annualPercent: 2.6, months: 240, nextDate: next, dueDay: 15),
                .init(name: "商业贷款", principal: 900_000_00, annualPercent: 3.1, months: 240, method: .equalPrincipal, nextDate: next, dueDay: 15)
            ], note: "演示利率与金额，仅用于预览布局。")
            try LiabilityStore.save(mortgage, name: "示例 · 自住房组合贷", kind: .mortgage, account: nil, reason: "", context: container.mainContext)
            let card = LiabilitySnapshot(balanceDate: date, installments: [
                .init(name: "家电分期", principal: 12000_00, months: 12, nextDate: LiabilityRules.date(date, offset: -4, day: 15), dueDay: 15, terms: .init(rate: 3.6, automatic: true)),
                .init(name: "旅行分期", principal: 3000_00, months: 6, nextDate: next, dueDay: 15, terms: .init(automatic: true))
            ], fixedInstallmentsOnly: true, cardRepaymentDay: 15)
            try LiabilityStore.save(card, name: "示例 · 信用卡", kind: .creditCard, account: nil, reason: "", context: container.mainContext)
            self.container = container
        } catch { errorMessage = error.localizedDescription }
    }
}
