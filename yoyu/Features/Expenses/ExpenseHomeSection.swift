import SwiftUI
import SwiftData

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
        let expenses = ExpectedExpenseRules.uncoveredExpenses(records, liabilities: accounts).map { record in
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
                Section { rows } header: { Text("预计支出") } footer: { Text(footerText) }.listRowBackground(AppTheme.cardBackground)
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
                    .font(.subheadline).foregroundStyle(AppTheme.secondaryText).padding(.vertical, 18)
            }
            if ExpectedExpenseRules.missingBills(accounts) {
                Label("部分账单待补全，仅计入已知金额", systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(AppTheme.secondaryText).padding(.top, 10)
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
        .foregroundStyle(AppTheme.primaryText)
        .buttonStyle(.plain)
    }

    private var ledgerHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("预测支出").font(.headline)
                Text("按已有计划预计").font(.caption).foregroundStyle(AppTheme.secondaryText)
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
                Image(systemName: icon).font(.subheadline).foregroundStyle(AppTheme.secondaryText).frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline)
                    Text(detail).font(.caption).foregroundStyle(AppTheme.secondaryText)
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
                NavigationLink { ExpenseDetailView(recordID: record.id) } label: {
                    VStack(alignment: .leading) {
                        ExpenseRow(record: record, date: clock.now)
                        if ExpectedExpenseRules.isCovered(record, liabilities: accounts) {
                            Text("已包含在负债还款中").font(.caption).foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
            }
            if cardLayout && (!accounts.isEmpty || !records.isEmpty) { Divider() }
            if records.isEmpty {
                Text("还可添加生活费、租金、保险等日常开支。")
                    .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            }
            NavigationLink("查看全部预计支出") { ExpectedExpenseView() }
            Button { adding = true } label: { Label("添加日常开支", systemImage: "plus") }
        }
    }
}
