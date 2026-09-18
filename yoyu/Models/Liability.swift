import Foundation
import SwiftData

enum LiabilityKind: String, Codable, CaseIterable, Identifiable {
    case mortgage, creditCard
    var id: String { rawValue }
    var title: String { self == .mortgage ? "房贷" : "信用卡" }
    var icon: String { self == .mortgage ? "house" : "creditcard" }
}

enum MortgageMethod: String, Codable, CaseIterable, Identifiable {
    case annuity, equalPrincipal
    var id: String { rawValue }
    var title: String { self == .annuity ? "等额本息" : "等额本金" }
}

struct MortgagePart: Codable, Identifiable {
    var id = UUID()
    var name = "商业贷款"
    var principal: Int64 = 0
    var annualPercent: Double = 0
    var months: Int = 240
    var method: MortgageMethod = .annuity
    var nextDate = Date()
    var dueDay = 1
    /// Optional bank-confirmed monthly principal for equal-principal loans.
    var fixedPrincipal: Int64?
}

enum InstallmentRateMode: String, Codable, CaseIterable, Identifiable {
    case annual, monthlyFee
    var id: String { rawValue }
    var title: String { self == .annual ? "年利率" : "每期手续费率" }
}

struct FixedInstallmentTerms: Codable {
    var rate: Double = 0
    var mode: InstallmentRateMode = .annual
    var paid: Int = 0
    /// nil preserves manually confirmed progress from earlier app versions.
    var automatic: Bool?
}

struct CardInstallment: Codable, Identifiable {
    var id = UUID()
    var name = ""
    var principal: Int64 = 0
    var months: Int = 12
    var nextDate = Date()
    var dueDay = 1
    var fixedPrincipal: Int64?
    var monthlyFee: Int64 = 0
    var firstFee: Int64?
    var lastFee: Int64?
    var terms: FixedInstallmentTerms?
}

struct LiabilitySnapshot: Codable {
    var balanceDate = Date()
    var mortgages: [MortgagePart] = []
    /// Bank's total outstanding, including all installment principal and posted charges.
    var cardTotal: Int64 = 0
    var billDue: Int64?
    var billDate = Date()
    var installments: [CardInstallment] = []
    var note = ""
    var fixedInstallmentsOnly: Bool?
    var cardRepaymentDay: Int?
}

@Model final class LiabilityAccount {
    var id: String = UUID().uuidString
    var name: String = ""
    var kindRaw: String = "mortgage"
    var snapshotData: Data?
    var historyData: Data?
    var modifiedAt: Date = Date()
    init() {}
    var kind: LiabilityKind? { LiabilityKind(rawValue: kindRaw) }
    var snapshot: LiabilitySnapshot? {
        guard let snapshotData else { return nil }
        return try? JSONDecoder().decode(LiabilitySnapshot.self, from: snapshotData)
    }
    var history: [LiabilityRevision]? {
        guard let historyData else { return [] }
        return try? JSONDecoder().decode([LiabilityRevision].self, from: historyData)
    }
}

struct LiabilityRevision: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var reason: String
    var snapshot: LiabilitySnapshot
}

struct DebtPayment: Identifiable {
    let id: String
    let sourceID: UUID?
    let name: String
    let date: Date
    let principal: Int64
    let interest: Int64
    let remaining: Int64?
    var total: Int64 { principal + interest }
}

enum LiabilityRules {
    static let maximum = ProfileRules.maximumMoneyCents
    static var calendar: Calendar { ProfileRules.calendar }
    static func accounts(_ accounts: [LiabilityAccount]) -> [LiabilityAccount] {
        Dictionary(grouping: accounts, by: \.id).values.compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    static func sum(_ values: [Int64]) -> Int64? {
        var sum: Int64 = 0
        for value in values {
            guard value >= 0, value <= maximum - sum else { return nil }
            sum += value
        }
        return sum
    }
    static func date(_ start: Date, offset: Int, day: Int) -> Date {
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: start))!
        let target = calendar.date(byAdding: .month, value: offset, to: month)!
        let days = calendar.range(of: .day, in: .month, for: target)!.count
        return calendar.date(byAdding: .day, value: min(max(day, 1), days) - 1, to: target)!
    }
    static func month(_ date: Date) -> Date { calendar.date(from: calendar.dateComponents([.year, .month], from: date))! }
    static func moneyValid(_ amount: Int64) -> Bool { (0...maximum).contains(amount) }
    static func balance(_ snapshot: LiabilitySnapshot, kind: LiabilityKind, on now: Date = Date()) -> Int64? {
        if kind == .mortgage { return sum(snapshot.mortgages.map(\.principal)) }
        if snapshot.fixedInstallmentsOnly == true {
            return sum(snapshot.installments.map { sum(installments($0, on: now).map(\.principal)) ?? maximum + 1 })
        }
        return moneyValid(snapshot.cardTotal) ? snapshot.cardTotal : nil
    }
    static func total(_ accounts: [LiabilityAccount], on now: Date = Date()) -> Int64? {
        var amounts: [Int64] = []
        for account in self.accounts(accounts) {
            guard let kind = account.kind, let snapshot = account.snapshot,
                  error(snapshot, kind: kind) == nil, let amount = balance(snapshot, kind: kind, on: now) else { return nil }
            amounts.append(amount)
        }
        return sum(amounts)
    }
    static func error(_ s: LiabilitySnapshot, kind: LiabilityKind) -> String? {
        if kind == .mortgage {
            guard !s.mortgages.isEmpty, s.mortgages.count <= 2 else { return "请至少填写一个贷款部分。" }
            for p in s.mortgages {
                guard moneyValid(p.principal), (1...600).contains(p.months),
                      p.annualPercent.isFinite, (0...30).contains(p.annualPercent),
                      (1...31).contains(p.dueDay) else { return "请检查贷款本金、利率（0–30%）和剩余期数（1–600期）。" }
                guard p.principal == 0 || calendar.startOfDay(for: p.nextDate) > calendar.startOfDay(for: s.balanceDate) else { return "下次还款日需晚于余额确认日期。" }
                if let fixed = p.fixedPrincipal, p.principal > 0 {
                    guard fixed > 0, fixed <= p.principal,
                          Decimal(fixed) * Decimal(p.months - 1) < Decimal(p.principal),
                          Decimal(fixed) * Decimal(p.months) >= Decimal(p.principal) - Decimal(p.months) else {
                        return "每期本金与剩余本金、期数不匹配，请核对银行计划；尾期允许补齐分币差额。"
                    }
                }
            }
            guard balance(s, kind: kind) != nil else { return "贷款本金合计超出支持范围。" }
        } else if s.fixedInstallmentsOnly == true {
            if let day = s.cardRepaymentDay {
                guard (1...31).contains(day), s.installments.allSatisfy({ $0.dueDay == day }) else {
                    return "请核对信用卡每月还款日。"
                }
            }
            guard !s.installments.isEmpty else { return "请至少添加一笔分期。" }
            for p in s.installments {
                guard !p.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      p.principal > 0, moneyValid(p.principal), (1...600).contains(p.months),
                      (1...31).contains(p.dueDay), let terms = p.terms,
                      (0...p.months).contains(terms.paid), terms.rate.isFinite,
                      (0...(terms.mode == .annual ? 30.0 : 5.0)).contains(terms.rate) else {
                    return "请核对商品金额、期数（1–600）、已还期数及利率；年利率支持 0–30%，每期手续费率支持 0–5%。"
                }
                guard sum(fullInstallments(p).map(\.total)) != nil else { return "分期还款总额超出支持范围。" }
            }
            guard balance(s, kind: kind) != nil else { return "剩余本金合计超出支持范围。" }
        } else {
            guard moneyValid(s.cardTotal), s.billDue.map({ moneyValid($0) && $0 <= s.cardTotal }) ?? true,
                  let installmentPrincipal = sum(s.installments.map(\.principal)), installmentPrincipal <= s.cardTotal else {
                return "总欠款必须包含全部分期本金，本期应还不能超过总欠款。"
            }
            for p in s.installments {
                guard !p.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      p.principal > 0, moneyValid(p.principal), (1...600).contains(p.months),
                      moneyValid(p.monthlyFee), p.firstFee.map(moneyValid) ?? true,
                      p.lastFee.map(moneyValid) ?? true, (1...31).contains(p.dueDay) else {
                    return "请补全分期名称、正数本金、剩余期数和费用。"
                }
                if let fixed = p.fixedPrincipal {
                    guard fixed > 0, Decimal(fixed) * Decimal(p.months - 1) < Decimal(p.principal),
                          Decimal(fixed) * Decimal(p.months) >= Decimal(p.principal) - Decimal(p.months) else {
                        return "分期每期本金与剩余本金、期数不匹配。"
                    }
                }
                guard sum([p.monthlyFee, p.principal]) != nil,
                      sum([p.firstFee ?? 0, p.principal]) != nil,
                      sum([p.lastFee ?? 0, p.principal]) != nil else { return "分期金额超出支持范围。" }
            }
            if let bill = s.billDue {
                let included = s.installments.flatMap { installments($0) }.filter { $0.date <= calendar.startOfDay(for: s.billDate) }
                guard let includedTotal = sum(included.map(\.total)), includedTotal <= bill else {
                    return "本期应还需包含还款日及之前的分期本息；请核对分期下次还款日或账单金额。"
                }
                let includedPrincipal = included.reduce(Int64(0)) { $0 + $1.principal }
                guard installmentPrincipal - includedPrincipal <= s.cardTotal - bill else {
                    return "扣除本期应还后，总欠款不足以覆盖未来分期本金，请核对银行总欠款。"
                }
            }
        }
        return nil
    }
    static func mortgage(_ p: MortgagePart) -> [DebtPayment] {
        guard p.principal > 0, moneyValid(p.principal), (1...600).contains(p.months),
              p.annualPercent.isFinite, (0...30).contains(p.annualPercent) else { return [] }
        let rate = p.annualPercent / 1200
        let monthly = rate == 0 ? Double(p.principal) / Double(p.months)
            : Double(p.principal) * rate / -expm1(-Double(p.months) * log1p(rate))
        let fixed = p.fixedPrincipal ?? Int64((Double(p.principal) / Double(p.months)).rounded(.down))
        var remaining = p.principal
        var rows: [DebtPayment] = []
        for i in 0..<p.months where remaining > 0 {
            let interest = Int64((Double(remaining) * rate).rounded())
            let principal = i == p.months - 1 ? remaining : min(remaining, max(0, p.method == .annuity ? Int64(monthly.rounded()) - interest : fixed))
            remaining -= principal
            rows.append(.init(id: "\(p.id)-\(i)", sourceID: p.id, name: p.name,
                              date: date(p.nextDate, offset: i, day: p.dueDay), principal: principal, interest: interest, remaining: remaining))
        }
        return rows
    }
    static func fullInstallments(_ p: CardInstallment) -> [DebtPayment] {
        guard let terms = p.terms, terms.rate.isFinite,
              (0...(terms.mode == .annual ? 30.0 : 5.0)).contains(terms.rate),
              moneyValid(p.principal), p.principal > 0, (1...600).contains(p.months) else { return [] }
        let loan = MortgagePart(id: p.id, name: p.name, principal: p.principal,
                               annualPercent: terms.mode == .annual ? terms.rate : 0,
                               months: p.months, nextDate: p.nextDate, dueDay: p.dueDay)
        let rows = mortgage(loan)
        guard terms.mode == .monthlyFee else { return rows }
        let fee = Int64((Double(p.principal) * terms.rate / 100).rounded())
        return rows.map { .init(id: $0.id, sourceID: $0.sourceID, name: $0.name, date: $0.date,
                               principal: $0.principal, interest: fee, remaining: $0.remaining) }
    }
    /// The entered installment is the next unpaid one; its date anchors the entire schedule.
    static func fromNextInstallment(_ plan: CardInstallment, period: Int, nextPayment: Date, day: Int) -> CardInstallment? {
        guard (1...600).contains(plan.months), (1...plan.months).contains(period),
              (1...31).contains(day), plan.terms != nil else { return nil }
        var result = plan
        result.dueDay = day
        result.nextDate = date(nextPayment, offset: -(period - 1), day: day)
        result.terms!.paid = period - 1
        return result
    }
    static func nextRepaymentDate(on now: Date, day: Int) -> Date {
        let due = date(now, offset: 0, day: day)
        return due < calendar.startOfDay(for: now) ? date(now, offset: 1, day: day) : due
    }

    static func hasAutomaticProgress(_ snapshot: LiabilitySnapshot) -> Bool {
        snapshot.fixedInstallmentsOnly == true && snapshot.installments.contains { $0.terms?.automatic == true }
    }
    static func paidCount(_ p: CardInstallment, on now: Date = Date()) -> Int {
        guard let terms = p.terms, (1...600).contains(p.months) else { return 0 }
        guard terms.automatic == true else { return min(p.months, max(0, terms.paid)) }
        let today = calendar.startOfDay(for: now)
        // The due day remains payable; only earlier days are presumed paid.
        return min(p.months, max(terms.paid, (0..<p.months).filter { date(p.nextDate, offset: $0, day: p.dueDay) < today }.count))
    }
    static func installments(_ p: CardInstallment, on now: Date = Date()) -> [DebtPayment] {
        if let terms = p.terms {
            guard (0...max(0, p.months)).contains(terms.paid) else { return [] }
            return Array(fullInstallments(p).dropFirst(paidCount(p, on: now)))
        }
        guard p.principal > 0, moneyValid(p.principal), (1...600).contains(p.months) else { return [] }
        let fixed = p.fixedPrincipal ?? p.principal / Int64(p.months)
        var remaining = p.principal
        return (0..<p.months).map { i in
            let principal = i == p.months - 1 ? remaining : min(remaining, max(0, fixed))
            remaining -= principal
            let fee = i == 0 ? p.firstFee ?? (p.months == 1 ? p.lastFee ?? p.monthlyFee : p.monthlyFee)
                : i == p.months - 1 ? p.lastFee ?? p.monthlyFee : p.monthlyFee
            return .init(id: "\(p.id)-\(i)", sourceID: p.id, name: p.name,
                         date: date(p.nextDate, offset: i, day: p.dueDay), principal: principal, interest: fee, remaining: remaining)
        }
    }
    static func payments(_ s: LiabilitySnapshot, kind: LiabilityKind, on now: Date = Date()) -> [DebtPayment] {
        guard error(s, kind: kind) == nil else { return [] }
        if kind == .mortgage { return s.mortgages.flatMap(mortgage).sorted { $0.date < $1.date } }
        var rows = s.installments.flatMap { installments($0, on: now) }
        if s.fixedInstallmentsOnly != true, let bill = s.billDue {
            // The confirmed bill already includes every installment due through this date.
            rows.removeAll { $0.date <= calendar.startOfDay(for: s.billDate) }
            if bill > 0 {
                rows.append(.init(id: "bill", sourceID: nil, name: "已录入账单", date: calendar.startOfDay(for: s.billDate), principal: bill, interest: 0, remaining: nil))
            }
        }
        return rows.sorted { $0.date < $1.date }
    }
    static func confirmed(_ s: LiabilitySnapshot, kind: LiabilityKind, on now: Date) -> LiabilitySnapshot? {
        guard error(s, kind: kind) == nil else { return nil }
        var result = s
        if kind == .mortgage {
            guard let next = s.mortgages.flatMap(mortgage).map(\.date).min(), next <= calendar.startOfDay(for: now) else { return nil }
            for i in result.mortgages.indices {
                guard let row = mortgage(result.mortgages[i]).first, row.date == next else { continue }
                // Keep the principal schedule stable after each confirmation.
                if result.mortgages[i].method == .equalPrincipal, result.mortgages[i].fixedPrincipal == nil {
                    result.mortgages[i].fixedPrincipal = row.principal > 0 ? row.principal : nil
                }
                result.mortgages[i].principal -= row.principal
                result.mortgages[i].months = max(1, result.mortgages[i].months - 1)
                result.mortgages[i].nextDate = date(result.mortgages[i].nextDate, offset: 1, day: result.mortgages[i].dueDay)
            }
            result.balanceDate = next
        } else if s.fixedInstallmentsOnly == true {
            guard let next = s.installments.filter({ $0.terms?.automatic != true }).flatMap({ installments($0, on: now) }).map(\.date).min(),
                  next <= calendar.startOfDay(for: now) else { return nil }
            for i in result.installments.indices {
                if result.installments[i].terms?.automatic != true, installments(result.installments[i], on: now).first?.date == next {
                    result.installments[i].terms!.paid += 1
                }
            }
            result.balanceDate = calendar.startOfDay(for: now)
        } else {
            guard let bill = s.billDue, bill > 0, calendar.startOfDay(for: s.billDate) <= calendar.startOfDay(for: now) else { return nil }
            result.cardTotal -= bill
            result.installments = s.installments.compactMap { p in
                let paid = installments(p).filter { $0.date <= calendar.startOfDay(for: s.billDate) }
                var updated = p
                updated.principal -= paid.reduce(0) { $0 + $1.principal }
                guard updated.principal > 0 else { return nil }
                if !paid.isEmpty {
                    let fixed = p.fixedPrincipal ?? p.principal / Int64(p.months)
                    updated.fixedPrincipal = fixed > 0 ? fixed : nil
                    updated.months -= paid.count
                    updated.nextDate = date(p.nextDate, offset: paid.count, day: p.dueDay)
                    updated.firstFee = nil
                }
                return updated
            }
            result.billDue = nil
            result.balanceDate = calendar.startOfDay(for: now)
        }
        return error(result, kind: kind) == nil ? result : nil
    }
}
