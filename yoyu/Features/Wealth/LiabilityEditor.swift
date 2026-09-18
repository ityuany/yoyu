import SwiftUI
import SwiftData

private struct LoanDraft: Identifiable {
    var id: UUID
    var name: String
    var principal: String
    var rate: String
    var months: String
    var method: MortgageMethod
    var nextDate: Date
    var fixedPrincipal: String
    var originalDate: Date
    var scheduledDay: Int
    init(_ p: MortgagePart) {
        originalDate = p.nextDate; scheduledDay = p.dueDay
        id = p.id; name = p.name; principal = ProfileRules.input(p.principal)
        rate = p.annualPercent.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never).precision(.fractionLength(0...8)))
        months = String(p.months); method = p.method; nextDate = p.nextDate
        fixedPrincipal = p.fixedPrincipal.map { ProfileRules.input($0) } ?? ""
    }
    var value: MortgagePart? {
        guard let principal = ProfileRules.scaledValue(principal), let rate = Double(rate), let months = Int(months),
              fixedPrincipal.isEmpty || ProfileRules.scaledValue(fixedPrincipal) != nil else { return nil }
        return MortgagePart(id: id, name: name, principal: principal, annualPercent: rate, months: months,
                            method: method, nextDate: nextDate, dueDay: nextDate == originalDate ? scheduledDay : LiabilityRules.calendar.component(.day, from: nextDate),
                            fixedPrincipal: method == .equalPrincipal ? ProfileRules.scaledValue(fixedPrincipal) : nil)
    }
}

private struct InstallmentDraft: Identifiable {
    var id: UUID
    var name: String
    var principal: String
    var months: String
    var nextDate: Date
    var fixedPrincipal: String
    var originalDate: Date
    var scheduledDay: Int
    var fee: String
    var firstFee: String
    var lastFee: String
    var rate: String
    var rateMode: InstallmentRateMode
    var paid: String
    var isFixed: Bool
    var automatic: Bool
    var nextPeriod: String
    var paymentDate: Date
    var settled: Bool
    init(_ p: CardInstallment) {
        let paidCount = LiabilityRules.paidCount(p)
        nextPeriod = String(min(p.months, paidCount + 1))
        settled = p.terms != nil && paidCount >= p.months
        paymentDate = LiabilityRules.installments(p).first?.date ?? LiabilityRules.nextRepaymentDate(on: Date(), day: p.dueDay)
        rate = String(p.terms?.rate ?? 0)
        rateMode = p.terms?.mode ?? .annual
        paid = String(p.terms?.paid ?? 0)
        isFixed = p.terms != nil
        automatic = p.terms?.automatic == true
        originalDate = p.nextDate; scheduledDay = p.dueDay
        id = p.id; name = p.name; principal = p.principal == 0 ? "" : ProfileRules.input(p.principal)
        months = String(p.months); nextDate = p.nextDate
        fixedPrincipal = p.fixedPrincipal.map { ProfileRules.input($0) } ?? ""
        fee = ProfileRules.input(p.monthlyFee)
        firstFee = p.firstFee.map { ProfileRules.input($0) } ?? ""
        lastFee = p.lastFee.map { ProfileRules.input($0) } ?? ""
    }
    var value: CardInstallment? {
        if isFixed {
            guard let amount = ProfileRules.scaledValue(principal), let count = Int(months),
                  let rate = Double(rate), let paid = Int(paid) else { return nil }
            return .init(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), principal: amount,
                         months: count, nextDate: nextDate,
                         dueDay: nextDate == originalDate ? scheduledDay : LiabilityRules.calendar.component(.day, from: nextDate),
                         terms: .init(rate: rate, mode: rateMode, paid: automatic ? 0 : paid, automatic: automatic))
        }
        guard let principal = ProfileRules.scaledValue(principal), let months = Int(months),
              let fee = ProfileRules.scaledValue(fee),
              [fixedPrincipal, firstFee, lastFee].allSatisfy({ $0.isEmpty || ProfileRules.scaledValue($0) != nil }) else { return nil }
        return .init(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), principal: principal,
                     months: months, nextDate: nextDate, dueDay: nextDate == originalDate ? scheduledDay : LiabilityRules.calendar.component(.day, from: nextDate),
                     fixedPrincipal: ProfileRules.scaledValue(fixedPrincipal), monthlyFee: fee,
                     firstFee: ProfileRules.scaledValue(firstFee), lastFee: ProfileRules.scaledValue(lastFee))
    }
}

struct LiabilityEditor: View {
    let kind: LiabilityKind
    let account: LiabilityAccount?
    private let fixedOnly: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CareerClock.self) private var clock
    @State private var repaymentDay: Int
    @State private var name: String
    @State private var balanceDate: Date
    @State private var loans: [LoanDraft]
    @State private var cardTotal: String
    @State private var billDue: String
    @State private var billDate: Date
    @State private var plans: [InstallmentDraft]
    @State private var note: String
    @State private var errorMessage: String?

    init(kind: LiabilityKind, account: LiabilityAccount? = nil) {
        self.kind = kind; self.account = account
        fixedOnly = account == nil || account?.snapshot?.fixedInstallmentsOnly == true
        let s = account?.snapshot ?? LiabilitySnapshot()
        _repaymentDay = State(initialValue: s.cardRepaymentDay ?? s.installments.first?.dueDay ?? 10)
        _name = State(initialValue: account?.name ?? "")
        _balanceDate = State(initialValue: s.balanceDate)
        let next = LiabilityRules.calendar.date(byAdding: .month, value: 1, to: Date())!
        let cardDay = s.cardRepaymentDay ?? s.installments.first?.dueDay ?? 10
        let cardNext = LiabilityRules.nextRepaymentDate(on: Date(), day: cardDay)
        let defaultLoan = MortgagePart(nextDate: next, dueDay: LiabilityRules.calendar.component(.day, from: next))
        _loans = State(initialValue: (account == nil && kind == .mortgage ? [defaultLoan] : s.mortgages).map(LoanDraft.init))
        _cardTotal = State(initialValue: account == nil ? "" : ProfileRules.input(s.cardTotal))
        _billDue = State(initialValue: s.billDue.map { ProfileRules.input($0) } ?? "")
        _billDate = State(initialValue: account == nil ? next : s.billDate)
        _plans = State(initialValue: (account == nil && kind == .creditCard ? [CardInstallment(nextDate: cardNext, dueDay: cardDay, terms: .init(automatic: true))] : s.installments).map(InstallmentDraft.init))
        _note = State(initialValue: s.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("账户") {
                    TextField(kind == .mortgage ? "名称，如自住房贷款" : "名称，如招商银行", text: $name)
                    if kind == .creditCard && fixedOnly {
                        Picker("每月还款日", selection: $repaymentDay) {
                            ForEach(1...31, id: \.self) { Text("每月 \($0) 日").tag($0) }
                        }
                    }
                    if kind == .mortgage || !fixedOnly { DatePicker("余额确认日期", selection: $balanceDate, in: ...Date(), displayedComponents: .date) }
                }
                if kind == .mortgage { mortgageForm } else if fixedOnly { fixedCardForm } else { cardForm }
                Section("备注") { TextField("选填", text: $note, axis: .vertical) }
                Section {
                    Text(kind == .mortgage
                         ? "按当前执行利率推算。调整利率或提前还款后，请按银行结果更新剩余本金、期数和下次还款日；旧记录会保留在校准历史中。"
                         : fixedOnly ? "自动推算假设每期正常还款，过了还款日计为已还，不代表银行实际扣款。月份不足指定天数时，使用月末。年利率按等额本息计算；手续费按分期总额计算。" : "总欠款包含所有分期剩余本金和已入账费用，不含尚未入账的未来费用。已录入的本期账单不会再叠加当期分期。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.neutralPageBackground()
            .onChange(of: repaymentDay) { _, day in
                for i in plans.indices {
                    let aligned = LiabilityRules.date(plans[i].paymentDate, offset: 0, day: day)
                    if !LiabilityRules.calendar.isDate(aligned, inSameDayAs: plans[i].paymentDate) {
                        plans[i].paymentDate = aligned
                    }
                }
            }
            .navigationTitle(account == nil ? "添加\(kind.title)" : "校准\(kind.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save) }
            }
            .saveErrorAlert($errorMessage)
        }
    }

    private var mortgageForm: some View {
        Group {
            ForEach($loans) { $loan in
                Section {
                    Picker("贷款部分", selection: $loan.name) {
                        Text("商业贷款").tag("商业贷款")
                        Text("公积金贷款").tag("公积金贷款")
                    }
                    moneyField("剩余本金", text: $loan.principal)
                    moneyField("年利率（%）", text: $loan.rate)
                    LabeledContent("剩余期数（月）") { TextField("期数", text: $loan.months).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    Picker("还款方式", selection: $loan.method) {
                        ForEach(MortgageMethod.allCases) { Text($0.title).tag($0) }
                    }
                    DatePicker("下次还款日", selection: $loan.nextDate, displayedComponents: .date)
                    if loan.method == .equalPrincipal {
                        moneyField("每期本金（选填）", text: $loan.fixedPrincipal)
                    }
                    if loans.count > 1 {
                        Button("移除这一部分", role: .destructive) { loans.removeAll { $0.id == loan.id } }
                    }
                } header: { Text(loan.name) } footer: {
                    Text("金额单位为人民币元。填写最近一次还款后的银行余额；每期本金留空则均分，尾期补齐。")
                }
            }
            if loans.count < 2 {
                Section {
                    Button("添加\(loans.first?.name == "商业贷款" ? "公积金" : "商业")贷款部分", systemImage: "plus") {
                        let next = LiabilityRules.calendar.date(byAdding: .month, value: 1, to: balanceDate)!
                        loans.append(LoanDraft(.init(name: loans.first?.name == "商业贷款" ? "公积金贷款" : "商业贷款", nextDate: next, dueDay: LiabilityRules.calendar.component(.day, from: next))))
                    }
                }
            }
        }
    }

    private func fixedValue(_ draft: InstallmentDraft) -> CardInstallment? {
        guard var value = draft.value, let period = Int(draft.nextPeriod) else { return nil }
        guard let anchored = LiabilityRules.fromNextInstallment(value, period: period,
                                                                nextPayment: draft.paymentDate, day: repaymentDay) else { return nil }
        value = anchored
        if draft.automatic && !draft.settled && LiabilityRules.date(draft.paymentDate, offset: 0, day: repaymentDay) < LiabilityRules.calendar.startOfDay(for: clock.now) {
            return nil
        }
        if draft.settled {
            value.terms?.paid = value.months
            value.terms?.automatic = false
        }
        return value
    }

    private var fixedCardForm: some View {
        Group {
            ForEach($plans) { $plan in
                Section {
                    TextField("商品名称，如手机", text: $plan.name)
                    moneyField("分期总额", text: $plan.principal)
                    moneyField("分期期数（月）", text: $plan.months)
                    Picker("计息方式", selection: $plan.rateMode) {
                        ForEach(InstallmentRateMode.allCases) { Text($0.title).tag($0) }
                    }
                    moneyField(plan.rateMode.title + "（%）", text: $plan.rate)
                    moneyField("当前待还第几期", text: $plan.nextPeriod)
                    DatePicker("预计下次还款日", selection: $plan.paymentDate, displayedComponents: .date)
                        .onChange(of: plan.paymentDate) { _, selected in
                            // A date change also updates the card's shared monthly repayment day.
                            let aligned = LiabilityRules.date(selected, offset: 0, day: repaymentDay)
                            if !LiabilityRules.calendar.isDate(aligned, inSameDayAs: selected) {
                                repaymentDay = LiabilityRules.calendar.component(.day, from: selected)
                            }
                        }
                    Toggle("后续按月自动推算", isOn: $plan.automatic)
                    if plan.settled { Text("此分期已结清").foregroundStyle(.secondary) }
                    if let value = fixedValue(plan),
                       LiabilityRules.error(LiabilitySnapshot(installments: [value], fixedInstallmentsOnly: true), kind: .creditCard) == nil {
                        let all = LiabilityRules.fullInstallments(value)
                        let remaining = LiabilityRules.installments(value, on: clock.now)
                        LabeledContent(plan.automatic ? "预计已还" : "已还", value: "\(LiabilityRules.paidCount(value, on: clock.now)) / \(value.months) 期")
                        if let first = all.first { LabeledContent("每期预计应还", value: ProfileRules.money(first.total)) }
                        LabeledContent("总利息／手续费", value: ProfileRules.money(LiabilityRules.sum(all.map(\.interest))))
                        LabeledContent("剩余本金", value: ProfileRules.money(LiabilityRules.sum(remaining.map(\.principal))))
                        LabeledContent("剩余应还（含息）", value: ProfileRules.money(LiabilityRules.sum(remaining.map(\.total))))
                    }
                    if plans.count > 1 {
                        Button("移除此分期", role: .destructive) { plans.removeAll { $0.id == plan.id } }
                    }
                } header: { Text(plan.name.isEmpty ? "固定分期" : plan.name) } footer: {
                    Text("例如第 5 期待还，表示前 4 期已还，剩余金额包含第 5 期。下次还款日可修改，不必填写最初开始日期。逾期未还请关闭自动推算。金额单位为元，免息填 0。")
                }
            }
            Section {
                Button("添加另一笔分期", systemImage: "plus") {
                    plans.append(InstallmentDraft(.init(nextDate: LiabilityRules.nextRepaymentDate(on: clock.now, day: repaymentDay), dueDay: repaymentDay, terms: .init(automatic: true))))
                }
            }
        }
    }

    private var cardForm: some View {
        Group {
            Section {
                moneyField("总欠款", text: $cardTotal)
                moneyField("本期应还（选填）", text: $billDue)
                DatePicker("本期还款日", selection: $billDate, displayedComponents: .date)
            } header: { Text("银行账单") } footer: {
                Text("金额单位为人民币元。本期应还填写含分期的剩余账单合计；留空表示未知，0 表示本期已还清。")
            }
            ForEach($plans) { $plan in
                Section {
                    TextField("分期名称", text: $plan.name)
                    moneyField("未还本金", text: $plan.principal)
                    LabeledContent("剩余期数（月）") { TextField("期数", text: $plan.months).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    DatePicker("下期分期还款日", selection: $plan.nextDate, displayedComponents: .date)
                    moneyField("每期本金（选填）", text: $plan.fixedPrincipal)
                    moneyField("每期费用", text: $plan.fee)
                    DisclosureGroup("首末期费用不同") {
                        moneyField("下期费用（选填）", text: $plan.firstFee)
                        moneyField("末期费用（选填）", text: $plan.lastFee)
                    }
                    Button("移除此分期", role: .destructive) { plans.removeAll { $0.id == plan.id } }
                } header: { Text(plan.name.isEmpty ? "分期计划" : plan.name) } footer: {
                    Text("每期费用为银行收取的利息／手续费。分期本金已包含在总欠款里，留空每期本金则均分；一次性费用填在下期费用中，其余期填 0。")
                }
            }
            Section {
                Button("添加分期计划", systemImage: "plus") {
                    plans.append(InstallmentDraft(.init(nextDate: billDate, dueDay: LiabilityRules.calendar.component(.day, from: billDate))))
                }
            }
        }
    }

    private func moneyField(_ title: String, text: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField("请输入", text: text).multilineTextAlignment(.trailing).keyboardType(.decimalPad)
                .frame(maxWidth: 130)
                .accessibilityLabel(title)
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { errorMessage = "请填写账户名称。"; return }
        var snapshot = LiabilitySnapshot(balanceDate: balanceDate, note: note)
        if kind == .mortgage {
            guard loans.allSatisfy({ $0.value != nil }) else { errorMessage = "请填写有效的本金、利率和期数。"; return }
            snapshot.mortgages = loans.compactMap(\.value)
            guard Set(snapshot.mortgages.map(\.name)).count == snapshot.mortgages.count else { errorMessage = "公积金和商业贷款各保留一个部分即可。"; return }
        } else if fixedOnly {
            guard plans.allSatisfy({ $0.value != nil }) else { errorMessage = "请填写有效的商品金额、期数和利率。"; return }
            guard plans.allSatisfy({ fixedValue($0) != nil }) else { errorMessage = "当前待还期数应在 1 到总期数之间；自动推算的下次还款日不能早于今天。"; return }
            snapshot.installments = plans.compactMap { fixedValue($0) }
            snapshot.cardRepaymentDay = repaymentDay
            snapshot.fixedInstallmentsOnly = true
            snapshot.balanceDate = Date()
        } else {
            guard let total = ProfileRules.scaledValue(cardTotal), billDue.isEmpty || ProfileRules.scaledValue(billDue) != nil,
                  plans.allSatisfy({ $0.value != nil }) else { errorMessage = "请检查欠款、期数和费用；金额最多保留两位小数。"; return }
            snapshot.cardTotal = total; snapshot.billDue = ProfileRules.scaledValue(billDue)
            snapshot.billDate = billDate; snapshot.installments = plans.compactMap(\.value)
        }
        if let error = LiabilityRules.error(snapshot, kind: kind) { errorMessage = error; return }
        do {
            try LiabilityStore.save(snapshot, name: cleanName, kind: kind, account: account, reason: "余额与计划校准", context: context)
            dismiss()
        } catch { errorMessage = "保存失败，原记录未改变：\(error.localizedDescription)" }
    }
}
