import SwiftUI
import SwiftData

struct ExpenseRow: View {
    let record: RecurringExpense
    let date: Date
    var monthView = false
    var body: some View {
        if let plan = record.plan {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "repeat").foregroundStyle(DashboardStyle.accent).frame(width: 22).padding(.top, 3)
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.name).foregroundStyle(.primary)
                    Text("\(plan.estimated ? "预估" : "固定") · \(plan.frequency.title) · \(monthView ? ExpenseRules.monthStatus(plan, in: date) : ExpenseRules.status(plan, on: date))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(ProfileRules.money(plan.amount)).monospacedDigit().foregroundStyle(.primary)
                    Text("/ \(plan.frequency.unit)").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 3)
        } else {
            Label("开支记录待核对", systemImage: "exclamationmark.circle")
        }
    }
}

struct ExpenseHomeSection: View {
    var cardLayout = false
    var onSelectCard: (() -> Void)?
    @Query private var records: [RecurringExpense]
    @Query private var liabilities: [LiabilityAccount]
    @Environment(CareerClock.self) private var clock
    @State private var adding = false
    private var accounts: [LiabilityAccount] { LiabilityRules.accounts(liabilities) }
    private struct PreviewItem: Identifiable {
        let sourceID: String
        let isRepayment: Bool
        let title: String
        let detail: String
        let icon: String
        let amount: Int64?
        var id: String { "\(isRepayment ? "repayment" : "expense"):\(sourceID)" }
    }

    private var previewItems: [PreviewItem] {
        let repayments = accounts.map { account in
            PreviewItem(sourceID: account.id, isRepayment: true, title: account.name,
                        detail: "\(account.kind?.title ?? "负债")还款", icon: account.kind?.icon ?? "creditcard",
                        amount: ExpectedExpenseRules.repayment(account, in: clock.now))
        }
        let expenses = ExpenseRules.records(records).map { record in
            PreviewItem(sourceID: record.id, isRepayment: false, title: record.plan?.name ?? "开支记录待核对",
                        detail: record.plan.map { $0.estimated ? "预估开支" : "固定开支" } ?? "待核对",
                        icon: "repeat", amount: record.plan.flatMap { ExpenseRules.amount($0, in: clock.now) })
        }
        return (repayments + expenses).sorted {
            // Unknown amounts follow known amounts; IDs make ties stable across refreshes.
            switch ($0.amount, $1.amount) {
            case let (lhs?, rhs?) where lhs != rhs: return lhs > rhs
            case (_?, nil): return true
            case (nil, _?): return false
            default: return $0.id < $1.id
            }
        }
    }

    var body: some View {
        Group {
            if cardLayout {
                ledger
                    .padding(.horizontal, 22)
            } else {
                Section { rows } header: { Text("预计支出") } footer: { Text(footerText) }
            }
        }
        .sheet(isPresented: $adding) { ExpenseEditor() }
    }

    private var ledger: some View {
        let items = previewItems
        return VStack(alignment: .leading, spacing: 0) {
            if let onSelectCard {
                Button(action: onSelectCard) { ledgerHeader }
                    .accessibilityHint("收起上方展开的卡片，支出保持展开")
            } else {
                NavigationLink { ExpectedExpenseView() } label: { ledgerHeader }
            }
            Divider()
            ForEach(Array(items.prefix(10))) { item in
                NavigationLink {
                    if item.isRepayment {
                        LiabilityDetailView(accountID: item.sourceID)
                    } else {
                        ExpenseDetailView(recordID: item.sourceID)
                    }
                } label: {
                    ledgerRow(item.title, detail: item.detail, icon: item.icon, amount: item.amount)
                }
            }
            if accounts.isEmpty && records.isEmpty {
                Text("安排生活费、租金或还款，让每月支出心中有数。")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 18)
            }
            if ExpectedExpenseRules.missingBills(accounts) {
                Label("部分账单待补全，仅计入已知金额", systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 10)
            }
            HStack {
                NavigationLink { ExpectedExpenseView() } label: {
                    HStack(spacing: 5) {
                        Text("查看全部 · 共 \(items.count) 项")
                        Image(systemName: "arrow.up.right").font(.caption2)
                    }.frame(minHeight: 44)
                }
                Spacer()
                Button { adding = true } label: {
                    Label("添加开支", systemImage: "plus").frame(minHeight: 44)
                }
            }
            .font(.subheadline)
            .padding(.top, 8)
        }
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
    }

    private var ledgerHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("本月支出").font(.headline)
                Text("按已有计划预计").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text(ExpectedExpenseRules.total(expenses: records, liabilities: accounts, in: clock.now).map { ProfileRules.money($0) } ?? "待核对")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
            if onSelectCard == nil {
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.bottom, 18)
        .contentShape(Rectangle())
    }

    private func ledgerRow(_ title: String, detail: String, icon: String, amount: Int64?) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.subheadline).foregroundStyle(.secondary).frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(amount.map { ProfileRules.money($0) } ?? "待核对")
                    .font(.subheadline).monospacedDigit()
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            Divider()
        }
    }

    private var footerText: String {
        ExpectedExpenseRules.missingBills(accounts)
            ? "含已有还款计划和日常开支；部分信用卡账单未录入，合计仅含已知部分。"
            : "自动汇总已有还款计划和日常开支，点击还款可查看原负债详情。"
    }

    private var rows: some View {
        Group {
            NavigationLink { ExpectedExpenseView() } label: {
                LabeledContent("本月预计支出", value: ExpectedExpenseRules.total(expenses: records, liabilities: accounts, in: clock.now).map { ProfileRules.money($0) } ?? "待核对")
            }
            if cardLayout { Divider() }
            ForEach(accounts) { account in
                NavigationLink { LiabilityDetailView(accountID: account.id) } label: {
                    RepaymentExpenseRow(account: account, month: clock.now)
                }
            }
            ForEach(Array(ExpenseRules.records(records).prefix(3))) { record in
                NavigationLink { ExpenseDetailView(recordID: record.id) } label: { ExpenseRow(record: record, date: clock.now) }
            }
            if cardLayout && (!accounts.isEmpty || !records.isEmpty) { Divider() }
            if records.isEmpty {
                Text("还可添加生活费、租金、保险等日常开支。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            NavigationLink("查看全部预计支出") { ExpectedExpenseView() }
            Button { adding = true } label: { Label("添加日常开支", systemImage: "plus") }
        }
    }
}

struct RepaymentExpenseRow: View {
    let account: LiabilityAccount
    let month: Date
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: account.kind?.icon ?? "creditcard").foregroundStyle(DashboardStyle.accent).frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                Text(account.name)
                Text("\(account.kind?.title ?? "负债")还款 · 自动引用").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(ExpectedExpenseRules.repayment(account, in: month).map { ProfileRules.money($0) } ?? "待核对").monospacedDigit()
        }.padding(.vertical, 3)
    }
}

struct ExpectedExpenseView: View {
    @Query private var records: [RecurringExpense]
    @Query private var liabilities: [LiabilityAccount]
    @State private var month: Date
    init(initialMonth: Date = Date()) {
        _month = State(initialValue: ExpenseRules.month(initialMonth))
    }
    @State private var adding = false
    private var accounts: [LiabilityAccount] { LiabilityRules.accounts(liabilities) }
    var body: some View {
        List {
            Section {
                HStack {
                    Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }.accessibilityLabel("上个月")
                    Spacer()
                    Text(ExpenseRules.monthLabel(month)).font(.headline)
                    Spacer()
                    Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }.accessibilityLabel("下个月")
                }.buttonStyle(.borderless)
                VStack(alignment: .leading, spacing: 8) {
                    Text("当月预计支出 · 含已知还款与预估开支").font(.subheadline).foregroundStyle(.secondary)
                    DashboardAmount(value: ExpectedExpenseRules.total(expenses: records, liabilities: accounts, in: month).map { ProfileRules.money($0) } ?? "待核对")
                }.padding(.vertical, 6)
            } footer: {
                Text("按当前已知计划汇总，包含还款本金与利息／费用。已确认并移出计划的还款不补记，不代表实际消费流水。")
            }
            Section {
                if accounts.isEmpty { Text("暂无负债还款计划").foregroundStyle(.secondary) }
                ForEach(accounts) { account in
                    NavigationLink { LiabilityDetailView(accountID: account.id) } label: { RepaymentExpenseRow(account: account, month: month) }
                }
                if ExpectedExpenseRules.missingBills(accounts) {
                    Label("部分信用卡账单未录入，当前仅计入已知还款。", systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.secondary)
                }
            } header: { Text("负债还款") }
            Section {
                ForEach(ExpenseRules.records(records)) { record in
                    NavigationLink { ExpenseDetailView(recordID: record.id) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ExpenseRow(record: record, date: month, monthView: true)
                            if let plan = record.plan {
                                Text("当月计入 \(ExpenseRules.amount(plan, in: month).map { ProfileRules.money($0) } ?? "待核对")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if records.isEmpty { Text("尚未添加日常开支，已有还款已计入上方合计。").font(.subheadline).foregroundStyle(.secondary) }
                Button { adding = true } label: { Label("添加日常开支", systemImage: "plus") }
                NavigationLink("管理日常开支") { ExpenseListView() }
                if records.isEmpty { NavigationLink("查看日常开支示例") { ExpenseExampleView() } }
            } header: { Text("日常开支") } footer: { Text("仅添加还款以外的开支，避免重复录入房贷或信用卡分期。") }
        }.neutralPageBackground()
        .navigationTitle("预计支出").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $adding) { ExpenseEditor() }
    }
    private func move(_ offset: Int) { month = ExpenseRules.calendar.date(byAdding: .month, value: offset, to: month)! }
}

struct ExpenseListView: View {
    var isExample = false
    @Environment(\.modelContext) private var context
    @Query private var records: [RecurringExpense]
    @State private var month = ExpenseRules.month(Date())
    @State private var adding = false
    private var items: [RecurringExpense] { ExpenseRules.records(records) }
    var body: some View {
        List {
            if isExample {
                Section { Label("示例计划 · 可体验编辑，不写入你的记录", systemImage: "sparkles").font(.subheadline) }
            }
            Section {
                HStack {
                    Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }.accessibilityLabel("上个月")
                    Spacer()
                    Text(ExpenseRules.monthLabel(month)).font(.headline).monospacedDigit()
                    Spacer()
                    Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }.accessibilityLabel("下个月")
                }.buttonStyle(.borderless)
                VStack(alignment: .leading, spacing: 8) {
                    Text("当月日常开支 · 含预估").font(.subheadline).foregroundStyle(.secondary)
                    DashboardAmount(value: ExpenseRules.total(items, in: month).map { ProfileRules.money($0) } ?? "待核对")
                }.padding(.vertical, 6)
            } footer: { Text("仅汇总当月日常开支，不含房贷与信用卡还款，不扣减现金余额。") }
            if items.isEmpty {
                Section { ContentUnavailableView("还没有日常开支", systemImage: "repeat", description: Text("添加一项开支，开始安排未来的生活。")) }
            }
            Section("开支计划") {
                ForEach(items) { record in
                    NavigationLink { ExpenseDetailView(recordID: record.id).modelContainer(context.container) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ExpenseRow(record: record, date: month, monthView: true)
                            if let plan = record.plan {
                                Text("当月计入 \(ExpenseRules.amount(plan, in: month).map { ProfileRules.money($0) } ?? "待核对") · \(ExpenseRules.period(plan))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }.neutralPageBackground()
        .navigationTitle("日常开支").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("添加", systemImage: "plus") { adding = true } } }
        .sheet(isPresented: $adding) { ExpenseEditor() }
    }
    private func move(_ offset: Int) { month = ExpenseRules.calendar.date(byAdding: .month, value: offset, to: month)! }
}

struct ExpenseDetailView: View {
    let recordID: String
    @Query private var records: [RecurringExpense]
    @Environment(CareerClock.self) private var clock
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var deleting = false
    @State private var errorMessage: String?
    private var record: RecurringExpense? { ExpenseRules.records(records).first { $0.id == recordID } }
    var body: some View {
        Group {
            if let record, let plan = record.plan {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(plan.estimated ? "预估金额" : "固定金额") · \(plan.frequency.title)").font(.subheadline).foregroundStyle(.secondary)
                            DashboardAmount(value: ProfileRules.money(plan.amount))
                            Text(ExpenseRules.status(plan, on: clock.now)).font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                    }
                    Section("发生时间") {
                        LabeledContent("开始日期", value: ExpenseRules.dateLabel(plan.start))
                        LabeledContent("结束日期", value: plan.end.map { ExpenseRules.dateLabel($0) } ?? "长期持续")
                        LabeledContent("发生方式", value: ExpenseRules.scheduleLabel(plan))
                    }
                    Section {
                        ForEach(0..<12, id: \.self) { offset in
                            let date = ExpenseRules.calendar.date(byAdding: .month, value: offset, to: ExpenseRules.month(clock.now))!
                            LabeledContent(ExpenseRules.monthLabel(date), value: ExpenseRules.amount(plan, in: date).map { ProfileRules.money($0) } ?? "待核对")
                                .monospacedDigit()
                        }
                    } header: { Text("未来 12 个月") } footer: {
                        Text("按当前计划估算，包含本月整月。未开始、已结束或没有扣款的月份计为零；不代表实际消费。")
                    }
                    if !plan.note.isEmpty { Section("备注") { Text(plan.note) } }
                    Section { Button("删除开支计划", role: .destructive) { deleting = true } }
                }.neutralPageBackground()
                .navigationTitle(plan.name).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .primaryAction) { Button("编辑") { editing = true } } }
                .sheet(isPresented: $editing) { ExpenseEditor(record: record) }
            } else {
                ContentUnavailableView("开支记录不可用", systemImage: "exclamationmark.circle", description: Text("记录可能已被删除或暂时无法读取。"))
            }
        }
        .alert("删除这项开支计划？", isPresented: $deleting) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                do { try ExpenseStore.delete(id: recordID, context: context); dismiss() }
                catch { errorMessage = error.localizedDescription }
            }
        } message: { Text("删除后，这项开支不再计入预计支出。不会修改现金或负债。") }
        .saveErrorAlert($errorMessage)
    }
}

/// A separate in-memory container allows exploration without changing the user's plans.
struct ExpenseExampleView: View {
    @State private var container: ModelContainer?
    @State private var failure: String?
    var body: some View {
        Group {
            if let container { ExpenseListView(isExample: true).modelContainer(container) }
            else if let failure { ContentUnavailableView("无法加载示例", systemImage: "exclamationmark.circle", description: Text(failure)) }
            else { ProgressView("准备示例…") }
        }.task {
            guard container == nil else { return }
            do {
                let schema = Schema([RecurringExpense.self])
                let sample = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
                let first = ExpenseRules.month(Date())
                let last = ExpenseRules.calendar.date(byAdding: .day, value: -1, to: ExpenseRules.calendar.date(byAdding: .month, value: 3, to: first)!)!
                for plan in [
                    ExpensePlan(name: "生活费", amount: 3000_00, start: first),
                    ExpensePlan(name: "异地租房", amount: 2000_00, estimated: false, start: first, end: last, spreadAcrossMonth: false, dueDay: 1),
                    ExpensePlan(name: "软件订阅", amount: 98_00, estimated: false, start: first, spreadAcrossMonth: false, dueDay: 8)
                ] { try ExpenseStore.save(plan, record: nil, context: sample.mainContext) }
                container = sample
            } catch { failure = error.localizedDescription }
        }
    }
}
