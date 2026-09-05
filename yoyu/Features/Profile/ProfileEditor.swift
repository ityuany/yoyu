import SwiftUI
import SwiftData

private struct ProfileDraft {
    var birthYear: Int?
    var birthMonth: Int?
    var gender = ""
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
    var workweekMask = 62
    var startMinutes = 540
    var endMinutes = 1080
    var followsHolidays = true

    init(_ profile: UserProfile?) {
        guard let profile else { return }
        birthYear = profile.birthYear
        birthMonth = profile.birthMonth
        gender = profile.gender
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
        workweekMask = profile.workweekMask
        startMinutes = profile.startMinutes
        endMinutes = profile.endMinutes
        followsHolidays = profile.followsHolidays
    }
}

struct ProfileEditor: View {
    let section: ProfileSection
    let profile: UserProfile?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProfileDraft
    @State private var errorMessage: String?
    private let weekdays = [(2, "周一"), (3, "周二"), (4, "周三"), (5, "周四"), (6, "周五"), (7, "周六"), (1, "周日")]

    init(section: ProfileSection, profile: UserProfile?) {
        self.section = section
        self.profile = profile
        _draft = State(initialValue: ProfileDraft(profile))
    }

    var body: some View {
        NavigationStack {
            Form {
                switch section {
                case .basic: basicFields
                case .employment: employmentFields
                case .wealth: wealthFields
                case .work: workFields
                }
                if let validationError {
                    Section { Text(validationError).foregroundStyle(.red) }
                }
            }
            .navigationTitle(section.rawValue)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(validationError != nil)
                }
            }
            .alert("未能保存", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
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
            } footer: {
                Text("出生年月和性别为必填项，用于计算预计退休年月。")
            }
            Section {
                LabeledContent("预计退休年月", value: retirement)
            } footer: {
                Text("按男性 63 岁、女性 58 岁推算。这是应用的预测口径，修改出生年月或性别后自动更新。")
            }
        }
    }

    private var employmentFields: some View {
        Group {
            Section("入职时间") {
                Toggle("填写入职时间", isOn: $draft.hasHireDate)
                if draft.hasHireDate { DatePicker("入职日期", selection: $draft.hireDate, displayedComponents: .date) }
            }
            Section {
                numberField("基本薪资", text: $draft.salary, unit: "元/月")
                numberField("养老金比例", text: $draft.pension, unit: "%")
                numberField("公积金比例", text: $draft.housing, unit: "%")
            } header: { Text("薪资待遇") } footer: {
                Text("基本薪资填写税前月薪；养老金和公积金仅填写个人缴纳比例。留空表示尚未填写，0 表示没有。")
            }
            Section("年终奖金") {
                numberField("奖金数额", text: $draft.bonus, unit: "元")
                Picker("发放月份", selection: $draft.bonusMonth) {
                    ForEach(1...12, id: \.self) { Text("\($0) 月").tag($0) }
                }
            }
        }
    }

    private var wealthFields: some View {
        Group {
            Section("现金") {
                numberField("现金", text: $draft.cash, unit: "元")
            }
            Section {
                numberField("持股数量", text: $draft.stockShares, unit: "股")
                numberField("单股价格", text: $draft.stockPrice, unit: "元/股")
                LabeledContent("股票市值", value: ProfileRules.money(stockValue))
                if let legacy = draft.legacyStockCents, !hasStockDetails {
                    Text("沿用此前填写的金额 \(ProfileRules.money(legacy))，补齐数量和单价后自动重新计算。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("清除旧股票金额", role: .destructive) { draft.legacyStockCents = nil }
                }
            } header: { Text("股票") } footer: {
                Text("市值 = 持股数量 × 单股价格。修改任一项时实时更新，金额四舍五入到分；数量和单价最多支持两位小数。")
            }
            Section {
                numberField("当前金额", text: $draft.investment, unit: "元")
                numberField("年化收益率", text: $draft.annualReturn, unit: "%", allowsNegative: true)
            } header: { Text("理财") } footer: {
                Text("年化收益率按百分比填写，例如 3.5 表示 3.5%，支持负值。收益率单独保存，当前财富仍按当前金额汇总。")
            }
            Section {
                LabeledContent("合计", value: ProfileRules.money(wealthTotal))
            } footer: {
                Text("未填写的项目不参与汇总，0 表示没有。")
            }
        }
    }

    private var workFields: some View {
        Group {
            Section("常规工作日") {
                ForEach(weekdays, id: \.0) { weekday, name in
                    Toggle(name, isOn: Binding(get: {
                        draft.workweekMask & (1 << (weekday - 1)) != 0
                    }, set: { selected in
                        if selected { draft.workweekMask |= 1 << (weekday - 1) }
                        else { draft.workweekMask &= ~(1 << (weekday - 1)) }
                    }))
                }
            }
            Section {
                DatePicker("上班时间", selection: timeBinding(start: true), displayedComponents: .hourAndMinute)
                DatePicker("下班时间", selection: timeBinding(start: false), displayedComponents: .hourAndMinute)
                if draft.endMinutes < draft.startMinutes { Text("下班时间为次日").font(.caption).foregroundStyle(.secondary) }
            } header: { Text("工作时段") }
            Section {
                Toggle("跟随国家节假日及调休", isOn: $draft.followsHolidays)
                NavigationLink("查看官方调休安排") { HolidayScheduleView() }
                NavigationLink("特殊日期调整") { WorkdayOverridesView(weekMask: draft.workweekMask, followsHolidays: draft.followsHolidays) }
            } footer: {
                Text("个人调整优先，其次是官方放假和补班安排，最后使用常规工作日。特殊日期调整单独保存。")
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

    private func timeBinding(start: Bool) -> Binding<Date> {
        Binding(get: {
            let minutes = start ? draft.startMinutes : draft.endMinutes
            return Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: minutes / 60, minute: minutes % 60))!
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            if start { draft.startMinutes = minutes } else { draft.endMinutes = minutes }
        })
    }

    private var retirement: String {
        guard let year = draft.birthYear, let month = draft.birthMonth, let age = ProfileRules.retirementAge(gender: draft.gender) else { return "请先填写出生年月与性别" }
        return "\(year + age) 年 \(month) 月"
    }
    private var hasStockDetails: Bool {
        !draft.stockShares.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !draft.stockPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var stockValue: Int64? {
        guard hasStockDetails else { return draft.legacyStockCents }
        return ProfileRules.stockValue(sharesHundredths: ProfileRules.scaledValue(draft.stockShares),
                                       priceCents: ProfileRules.scaledValue(draft.stockPrice))
    }
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
            if year * 12 + month > now.year! * 12 + now.month! { return "出生年月不能晚于当前月份。" }
            return nil
        case .work:
            return draft.startMinutes == draft.endMinutes ? "上下班时间不能相同。" : nil
        case .employment:
            fields = [("基本薪资", draft.salary, 100_000_000_000_00), ("养老金比例", draft.pension, 10_000), ("公积金比例", draft.housing, 10_000), ("年终奖金", draft.bonus, 100_000_000_000_00)]
        case .wealth:
            if hasStockDetails {
                guard ProfileRules.scaledValue(draft.stockShares) != nil else { return "请填写有效的持股数量，最多两位小数且不超过 1000 亿股。" }
                guard ProfileRules.scaledValue(draft.stockPrice) != nil else { return "请填写有效的单股价格，最多两位小数且不超过 1000 亿元。" }
                if stockValue == nil { return "股票市值不能超过 1000 亿元。" }
            }
            if !draft.annualReturn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ProfileRules.annualReturnRate(draft.annualReturn) == nil {
                return "年化收益率请输入 -100—100，最多两位小数。"
            }
            fields = [("现金", draft.cash, 100_000_000_000_00), ("理财", draft.investment, 100_000_000_000_00)]
        }
        for (name, text, maximum) in fields where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if ProfileRules.scaledValue(text, maximum: maximum) == nil {
                return maximum == 10_000 ? "\(name)请输入 0—100，最多两位小数。" : "\(name)请输入有效的非负金额，最多两位小数且不超过 1000 亿元。"
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
        case .employment:
            record.employmentUpdatedAt = Date()
            record.hireDate = draft.hasHireDate ? draft.hireDate : nil
            record.salaryCents = ProfileRules.scaledValue(draft.salary)
            record.pensionBasisPoints = ProfileRules.scaledValue(draft.pension)
            record.housingBasisPoints = ProfileRules.scaledValue(draft.housing)
            record.bonusCents = ProfileRules.scaledValue(draft.bonus)
            record.bonusMonth = draft.bonusMonth
        case .wealth:
            record.wealthUpdatedAt = Date()
            record.cashCents = ProfileRules.scaledValue(draft.cash)
            record.stockSharesHundredths = ProfileRules.scaledValue(draft.stockShares)
            record.stockPriceCents = ProfileRules.scaledValue(draft.stockPrice)
            record.stockCents = hasStockDetails ? nil : draft.legacyStockCents
            record.investmentCents = ProfileRules.scaledValue(draft.investment)
            record.investmentAnnualReturnBasisPoints = ProfileRules.annualReturnRate(draft.annualReturn)
        case .work:
            record.workUpdatedAt = Date()
            record.workweekMask = draft.workweekMask
            record.startMinutes = draft.startMinutes
            record.endMinutes = draft.endMinutes
            record.followsHolidays = draft.followsHolidays
        }
        do { try context.save(); dismiss() }
        catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}
