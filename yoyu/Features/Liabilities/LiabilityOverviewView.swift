import SwiftUI
import SwiftData

struct LiabilityOverviewView: View {
    @Environment(CareerClock.self) private var clock
    @Environment(\.modelContext) private var context
    var filter: LiabilityKind? = nil
    var isExample = false
    @Query private var records: [LiabilityAccount]
    @State private var adding: LiabilityKind?
    @State private var openedMortgage: LiabilityAccount?
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
                        if kind == .mortgage {
                            MortgageCertificateCard(account: account, date: clock.now) {
                                openedMortgage = account
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            NavigationLink {
                                LiabilityDetailView(accountID: account.id).modelContext(context)
                            } label: {
                                HStack {
                                    Label(account.name, systemImage: kind.icon)
                                    Spacer()
                                    Text(account.snapshot.flatMap { LiabilityRules.balance($0, kind: kind, on: clock.now) }.map { ProfileRules.money($0, compact: true) } ?? "待核对")
                                        .foregroundStyle(.secondary).monospacedDigit()
                                }
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
        .navigationDestination(item: $openedMortgage) { account in
            LiabilityDetailView(accountID: account.id).modelContext(context)
        }
    }
}
