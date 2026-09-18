import SwiftUI
import SwiftData

private struct ProfileDraft {
    var birthYear: Int?
    var birthMonth: Int?
    var gender = ""
    var femaleRetirementAge: Int?
    var hasHireDate = false
    var hireDate = Date()
    var salary = ""
    var pension = ""
    var housing = ""
    var bonus = ""
    var bonusMonth = 12
    var cash = ""
    var stockShares = ""
    var stockPrice = ""
    var legacyStockCents: Int64?
    var investment = ""
    var annualReturn = ""
    var workweek = Workweek.default
    var startMinutes = 540
    var endMinutes = 1080
    var followsHolidays = true

    init(_ profile: UserProfile?) {
        guard let profile else { return }
        birthYear = profile.birthYear
        birthMonth = profile.birthMonth
        gender = profile.gender
        femaleRetirementAge = profile.femaleRetirementAge
        hasHireDate = profile.hireDate != nil
        hireDate = profile.hireDate ?? Date()
        salary = ProfileRules.input(profile.salaryCents)
        pension = ProfileRules.input(profile.pensionBasisPoints)
        housing = ProfileRules.input(profile.housingBasisPoints)
        bonus = ProfileRules.input(profile.bonusCents)
        bonusMonth = profile.bonusMonth
        cash = ProfileRules.input(profile.cashCents)
        stockShares = ProfileRules.input(profile.stockSharesHundredths)
        stockPrice = ProfileRules.input(profile.stockPriceCents)
        if profile.stockSharesHundredths == nil && profile.stockPriceCents == nil {
            legacyStockCents = profile.stockCents
        }
        investment = ProfileRules.input(profile.investmentCents)
        annualReturn = ProfileRules.input(profile.investmentAnnualReturnBasisPoints)
        workweek = profile.workweek
        startMinutes = profile.startMinutes
        endMinutes = profile.endMinutes
        followsHolidays = profile.followsHolidays
    }
}

enum WealthEditScope: String, Identifiable {
    case cash, investment
    var id: String { rawValue }
    var title: String { self == .cash ? "更新现金余额" : "更新理财资产" }
}

struct ProfileEditor: View {
    var wealthScope: WealthEditScope?
    let section: ProfileSection
    let profile: UserProfile?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var stocks: [StockHolding]
    @Environment(CareerClock.self) private var clock
    @State private var draft: ProfileDraft
    @State private var errorMessage: String?

    init(section: ProfileSection, profile: UserProfile?, wealthScope: WealthEditScope? = nil) {
        self.wealthScope = wealthScope
        self.section = section
        self.profile = profile
        _draft = State(initialValue: ProfileDraft(profile))
    }

    var body: some View {
        NavigationStack {
            Form {
                switch section {
                case .basic: basicFields
                case .employment: Text("请在企业履历中编辑薪资待遇。")
                case .wealth: wealthFields
                case .work: Text("请在企业履历中编辑工作安排。")
                }
                if let validationError {
                    Section { Text(validationError).foregroundStyle(.red) }
                }
            }.neutralPageBackground()
            .navigationTitle(wealthScope?.title ?? section.rawValue)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(validationError != nil)
                }
            }
            .saveErrorAlert($errorMessage)
        }
    }

    private var basicFields: some View {
        Group {
            Section {
                Menu {
                    ForEach((1900...ProfileRules.calendar.component(.year, from: Date())).reversed(), id: \.self) { year in
                        Button("\(String(year)) 年") { draft.birthYear = year }
                    }
                } label: {
                    LabeledContent("出生年份", value: draft.birthYear.map { "\($0) 年" } ?? "请选择")
                }
                Menu {
                    ForEach(1...12, id: \.self) { month in
                        Button("\(month) 月") { draft.birthMonth = month }
                    }
                } label: {
                    LabeledContent("出生月份", value: draft.birthMonth.map { "\($0) 月" } ?? "请选择")
                }
                Menu {
                    Button("男") { draft.gender = "男" }
                    Button("女") { draft.gender = "女" }
                } label: {
                    LabeledContent("性别", value: draft.gender.isEmpty ? "请选择" : draft.gender)
                }
                if draft.gender == "女" {
                    Picker("原法定退休年龄", selection: $draft.femaleRetirementAge) {
                        Text("请选择").tag(nil as Int?)
                        Text("50 岁类别").tag(50 as Int?)
                        Text("55 岁类别").tag(55 as Int?)
                    }
                }
                LabeledContent("法定退休年月", value: retirement)
            } footer: {
                Text("按中国大陆普通职工渐进式延迟退休规则计算。女性需选择原法定退休年龄类别；不含特殊工种等提前退休情形。")
            }
        }
    }

    private var wealthFields: some View {
        Group {
            if wealthScope != .investment {
                Section("现金") { numberField("当前余额", text: $draft.cash, unit: "元") }
            }
            if wealthScope == nil {
            Section("股票") {
                LabeledContent("已归属价值", value: ProfileRules.money(stockValue))
                Text("股票与归属计划请在当前财富详情中单独管理。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            }
            if wealthScope != .cash {
            Section {
                numberField("当前金额", text: $draft.investment, unit: "元")
                numberField("年化收益率", text: $draft.annualReturn, unit: "%", allowsNegative: true)
            } header: { Text("理财") } footer: {
                Text("年化收益率按百分比填写，例如 3.5 表示 3.5%，支持负值。收益率单独保存，当前财富仍按当前金额汇总。")
            }
            }
            Section {
                if wealthScope == nil { LabeledContent("合计", value: ProfileRules.money(wealthTotal)) }
            } footer: {
                Text("未填写的项目不参与汇总，0 表示没有。")
            }
        }
    }

    private func numberField(_ title: String, text: Binding<String>, unit: String, allowsNegative: Bool = false) -> some View {
        LabeledContent {
            HStack {
                TextField("待填写", text: text)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 80)
                    .accessibilityLabel(title)
                    #if os(iOS)
                    .keyboardType(allowsNegative ? .numbersAndPunctuation : .decimalPad)
                    #endif
                Text(unit).foregroundStyle(.secondary).fixedSize()
            }
        } label: { Text(title) }
    }

    private var retirement: String {
        ProfileRules.statutoryRetirement(year: draft.birthYear, month: draft.birthMonth, gender: draft.gender, femaleAge: draft.femaleRetirementAge)
    }
    private var stockValue: Int64? {
        StockRules.portfolio(stocks, profile: profile, on: clock.now)
    }
    /// 将已填写的现金、股票和理财金额求和，空字段不纳入汇总。
    private var wealthTotal: Int64? {
        let values = [ProfileRules.scaledValue(draft.cash), stockValue, ProfileRules.scaledValue(draft.investment)].compactMap { $0 }
        return values.isEmpty ? nil : values.reduce(0, +)
    }
    private var validationError: String? {
        let fields: [(String, String, Int64)]
        switch section {
        case .basic:
            guard let year = draft.birthYear, let month = draft.birthMonth,
                  ProfileRules.retirementAge(gender: draft.gender) != nil else {
                return "请填齐出生年月和性别后保存。"
            }
            let now = ProfileRules.calendar.dateComponents([.year, .month], from: Date())
            guard (1900...now.year!).contains(year), (1...12).contains(month) else { return "请选择有效的出生年月。" }
            // 把年月映射为总月份数，便于直接比较是否晚于当前月份。
            if year * 12 + month > now.year! * 12 + now.month! { return "出生年月不能晚于当前月份。" }
            return nil
        case .work, .employment:
            return "请在企业履历中编辑。"
        case .wealth:
            if wealthScope != .cash && !draft.annualReturn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ProfileRules.annualReturnRate(draft.annualReturn) == nil {
                return "年化收益率请输入 -100—100，最多两位小数。"
            }
            fields = wealthScope == .cash ? [("现金", draft.cash, ProfileRules.maximumMoneyCents)] : wealthScope == .investment ? [("理财", draft.investment, ProfileRules.maximumMoneyCents)] : [("现金", draft.cash, ProfileRules.maximumMoneyCents), ("理财", draft.investment, ProfileRules.maximumMoneyCents)]
        }
        for (name, text, maximum) in fields where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if ProfileRules.scaledValue(text, maximum: maximum) == nil {
                return maximum == ProfileRules.maximumPercentBasisPoints
                    ? "\(name)请输入 0—100，最多两位小数。"
                    : "\(name)请输入有效的非负金额，最多两位小数且不超过 1000 亿元。"
            }
        }
        return nil
    }

    private func save() {
        guard validationError == nil else { return }
        let record = profile ?? UserProfile()
        if profile == nil { context.insert(record) }
        switch section {
        case .basic:
            record.basicUpdatedAt = Date()
            record.birthYear = draft.birthYear
            record.birthMonth = draft.birthMonth
            record.gender = draft.gender
            record.femaleRetirementAge = draft.femaleRetirementAge
        case .wealth:
            record.wealthUpdatedAt = Date()
            if wealthScope != .investment { record.cashCents = ProfileRules.scaledValue(draft.cash) }
            if wealthScope != .cash {
                record.investmentCents = ProfileRules.scaledValue(draft.investment)
                record.investmentAnnualReturnBasisPoints = ProfileRules.annualReturnRate(draft.annualReturn)
            }
        case .work, .employment:
            return
        }
        if let message = context.saveOrRollback() { errorMessage = message } else { dismiss() }
    }
}
