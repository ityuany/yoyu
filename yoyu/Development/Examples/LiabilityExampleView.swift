import SwiftUI
import SwiftData

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
            try LiabilityStore.save(mortgage, name: "示例 · 自住房组合贷", kind: .mortgage, account: nil, context: container.mainContext)
            let card = LiabilitySnapshot(balanceDate: date, installments: [
                .init(name: "家电分期", principal: 12000_00, months: 12, nextDate: LiabilityRules.date(date, offset: -4, day: 15), dueDay: 15, terms: .init(rate: 3.6, automatic: true)),
                .init(name: "旅行分期", principal: 3000_00, months: 6, nextDate: next, dueDay: 15, terms: .init(automatic: true))
            ], fixedInstallmentsOnly: true, cardRepaymentDay: 15)
            try LiabilityStore.save(card, name: "示例 · 信用卡", kind: .creditCard, account: nil, context: container.mainContext)
            self.container = container
        } catch { errorMessage = error.localizedDescription }
    }
}
