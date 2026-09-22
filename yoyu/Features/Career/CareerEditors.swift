import SwiftUI
import SwiftData

struct EmploymentEditor: View {
    let job: Employment?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var jobs: [Employment]
    @Query private var stages: [SalaryStage]
    @State private var salaryPaymentDay: Int
    @State private var name: String
    @State private var start: Date
    @State private var ended: Bool
    @State private var end: Date
    @State private var error: String?
    init(job: Employment?) {
        self.job = job
        _salaryPaymentDay = State(initialValue: job?.salaryPaymentDay ?? 10)
        _name = State(initialValue: job?.name ?? "")
        _start = State(initialValue: job?.start ?? Date())
        _ended = State(initialValue: job?.end != nil)
        _end = State(initialValue: job?.end ?? Date())
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("企业信息") {
                    TextField("企业名称", text: $name)
                    DatePicker("入职日期", selection: $start, in: ...Date(), displayedComponents: .date)
                    Toggle("已经离职", isOn: $ended)
                    if ended { DatePicker("离职日期", selection: $end, in: ...Date(), displayedComponents: .date) }
                }
                Section {
                    Picker("每月发薪日", selection: $salaryPaymentDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text("每月 \(day) 号").tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("employment.payday")
                } footer: {
                    Text("适用于这家公司的所有薪资阶段。遇到当月没有的日期，按月末计算。")
                }
                Section {
                    Text("保存任职经历后，可在详情中录入薪资阶段和工作安排。")
                        .foregroundStyle(.secondary)
                }
                if let validation { Section { Text(validation).foregroundStyle(.red) } }
            }.neutralPageBackground()
            .environment(\.calendar, ProfileRules.calendar)
            .environment(\.timeZone, ProfileRules.calendar.timeZone)
            .navigationTitle(job == nil ? "添加任职经历" : "编辑任职信息")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save).disabled(validation != nil) }
            }
            .saveErrorAlert($error)
        }
    }
    private var validation: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请填写企业名称。" }
        return CareerRules.employmentError(start: ProfileRules.calendar.startOfDay(for: start), end: ended ? ProfileRules.calendar.startOfDay(for: end) : nil, id: job?.id, others: jobs, stages: stages)
    }
    private func save() {
        guard validation == nil else { return }
        let value = job ?? Employment()
        if job == nil { context.insert(value) }
        value.salaryPaymentDay = salaryPaymentDay
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.start = ProfileRules.calendar.startOfDay(for: start)
        value.end = ended ? ProfileRules.calendar.startOfDay(for: end) : nil
        value.modifiedAt = Date()
        if let message = context.saveOrRollback() { error = message } else { dismiss() }
    }
}

struct SalaryEditor: View {
    let job: Employment
    let stage: SalaryStage?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var stages: [SalaryStage]
    @State private var date: Date
    @State private var hasDate: Bool
    @State private var salary: String
    @State private var pension: String
    @State private var housing: String
    @State private var bonus: String
    @State private var bonusMonth: Int
    @State private var reason: String
    @State private var error: String?
    @State private var confirmingDeletion = false
    init(job: Employment, stage: SalaryStage?, previous: SalaryStage?) {
        self.job = job
        self.stage = stage
        let source = stage ?? previous
        _hasDate = State(initialValue: stage == nil || stage?.effectiveDate != nil)
        _date = State(initialValue: stage?.effectiveDate ?? job.end ?? Date())
        _salary = State(initialValue: ProfileRules.input(source?.salaryCents))
        _pension = State(initialValue: ProfileRules.input(source?.pensionBasisPoints))
        _housing = State(initialValue: ProfileRules.input(source?.housingBasisPoints))
        _bonus = State(initialValue: ProfileRules.input(source?.bonusCents))
        _bonusMonth = State(initialValue: source?.bonusMonth ?? 12)
        _reason = State(initialValue: stage?.reason ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("生效时间") {
                    if stage != nil && stage?.effectiveDate == nil {
                        Toggle("补充生效日期", isOn: $hasDate)
                    }
                    if hasDate { DatePicker("生效日期", selection: $date, displayedComponents: .date) }
                    else { Text("保留未知日期，确认后再补充。").foregroundStyle(.secondary) }
                }
                Section {
                    number("税前月薪", text: $salary, unit: "元/月")
                    number("养老金个人比例", text: $pension, unit: "%")
                    number("公积金个人比例", text: $housing, unit: "%")
                } header: { Text("薪资待遇") } footer: {
                    Text("留空表示未知，0 表示没有。个人月缴纳金额按基本薪资和比例估算。")
                }
                Section("年终奖") {
                    number("奖金数额", text: $bonus, unit: "元")
                    Picker("发放月份", selection: $bonusMonth) { ForEach(1...12, id: \.self) { Text("\($0) 月").tag($0) } }
                }
                Section {
                    TextField("调整原因（选填）", text: $reason)
                } footer: {
                    Text(stage == nil ? "新增阶段会保留原有薪资。未来日期的待遇在生效前不会用于当前薪资。" : "此操作修改已有记录，不会新增一次调薪。")
                }
                if let validation { Section { Text(validation).foregroundStyle(.red) } }
                if stage != nil {
                    Section {
                        Button("删除薪资阶段", role: .destructive) { confirmingDeletion = true }
                    }
                }
            }.neutralPageBackground()
            .environment(\.calendar, ProfileRules.calendar)
            .environment(\.timeZone, ProfileRules.calendar.timeZone)
            .navigationTitle(stage == nil ? "新增薪资阶段" : "修改薪资记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save).disabled(validation != nil) }
            }
            .confirmationDialog("删除这一薪资阶段？", isPresented: $confirmingDeletion, titleVisibility: .visible) {
                Button("删除薪资阶段", role: .destructive) { deleteStage() }
                Button("取消", role: .cancel) { }
            } message: {
                Text("此操作无法撤销，企业履历和其他薪资阶段会保留。删除后将按剩余阶段重新计算收入；若没有适用阶段，将显示待补全。本页未保存的修改不会保留。")
            }
            .saveErrorAlert($error)
        }
    }
    private func deleteStage() {
        guard let stage else { return }
        do {
            try CareerRules.deleteStage(id: stage.id, employmentID: job.id, context: context)
            dismiss()
        } catch {
            self.error = "删除失败，请重试。\(error.localizedDescription)"
        }
    }

    private func number(_ title: String, text: Binding<String>, unit: String) -> some View {
        LabeledContent {
            HStack {
                TextField("待填写", text: text).multilineTextAlignment(.trailing).accessibilityLabel(title)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Text(unit).foregroundStyle(.secondary).fixedSize()
            }
        } label: { Text(title) }
    }
    private var validation: String? {
        for (name, value, max) in [("月薪", salary, ProfileRules.maximumMoneyCents), ("养老比例", pension, ProfileRules.maximumPercentBasisPoints), ("公积金比例", housing, ProfileRules.maximumPercentBasisPoints), ("奖金", bonus, ProfileRules.maximumMoneyCents)] {
            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ProfileRules.scaledValue(value, maximum: max) == nil {
                return "\(name)需为非负数，最多两位小数；比例不超过 100%，金额不超过 1000 亿元。"
            }
        }
        guard hasDate else { return nil }
        return CareerRules.stageError(date: ProfileRules.calendar.startOfDay(for: date), id: stage?.id, job: job, stages: stages)
    }
    private func save() {
        guard validation == nil else { return }
        let value = stage ?? SalaryStage()
        if stage == nil { context.insert(value) }
        value.employmentID = job.id
        value.effectiveDate = hasDate ? ProfileRules.calendar.startOfDay(for: date) : nil
        value.salaryCents = ProfileRules.scaledValue(salary)
        value.pensionBasisPoints = ProfileRules.scaledValue(pension, maximum: ProfileRules.maximumPercentBasisPoints)
        value.housingBasisPoints = ProfileRules.scaledValue(housing, maximum: ProfileRules.maximumPercentBasisPoints)
        value.bonusCents = ProfileRules.scaledValue(bonus)
        value.bonusMonth = bonusMonth
        value.reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasDate && value.reason == "沿用原有待遇，生效日期待补充" { value.reason = "" }
        value.modifiedAt = Date()
        if let message = context.saveOrRollback() { error = message } else { dismiss() }
    }
}

struct EmploymentWorkEditor: View {
    let job: Employment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var followsHolidays: Bool
    @State private var week: Workweek
    @State private var start: Date
    @State private var end: Date
    @State private var error: String?
    init(job: Employment) {
        self.job = job
        _followsHolidays = State(initialValue: job.followsHolidays)
        _week = State(initialValue: Workweek(mask: job.workweekMask))
        _start = State(initialValue: ProfileRules.calendar.date(byAdding: .minute, value: job.startMinutes, to: ProfileRules.calendar.startOfDay(for: Date()))!)
        _end = State(initialValue: ProfileRules.calendar.date(byAdding: .minute, value: job.endMinutes, to: ProfileRules.calendar.startOfDay(for: Date()))!)
    }
    private func minutes(_ date: Date) -> Int {
        let parts = ProfileRules.calendar.dateComponents([.hour, .minute], from: date)
        return parts.hour! * 60 + parts.minute!
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("工作日") {
                    ForEach(Weekday.displayOrder) { day in
                        Toggle(day.name, isOn: Binding(get: { week.contains(day) }, set: { week.set(day, isWorkday: $0) }))
                    }
                }
                Section {
                    Toggle("遵循法定节假日及调休", isOn: $followsHolidays)
                } footer: {
                    Text("开启后，放假日不计为工作日，调休补班日计为工作日。当前收录 2026 年安排，其他年份按每周工作日估算。")
                }
                Section("工作时间") {
                    DatePicker("上班时间", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("下班时间", selection: $end, displayedComponents: .hourAndMinute)
                    if minutes(end) < minutes(start) { Text("下班时间为次日").foregroundStyle(.secondary) }
                    if minutes(end) == minutes(start) { Text("上下班时间不能相同。").foregroundStyle(.red) }
                }
            }.neutralPageBackground()
            .environment(\.timeZone, ProfileRules.calendar.timeZone)
            .navigationTitle("工作安排")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard minutes(start) != minutes(end) else { return }
                        job.followsHolidays = followsHolidays
                        job.workweekMask = week.mask
                        job.startMinutes = minutes(start)
                        job.endMinutes = minutes(end)
                        job.modifiedAt = Date()
                        if let message = context.saveOrRollback() { error = message } else { dismiss() }
                    }.disabled(minutes(start) == minutes(end))
                }
            }
            .saveErrorAlert($error)
        }
    }
}

#if DEBUG
struct EmploymentPaydayTestHost: View {
    private let container: ModelContainer = {
        let schema = Schema([Employment.self, SalaryStage.self, StockHolding.self, UserProfile.self])
        let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let job = Employment()
        job.name = "发薪日测试企业"
        job.start = ProfileRules.date(2024, 1, 1)
        container.mainContext.insert(job)
        for year in [2024, 2025] {
            let stage = SalaryStage()
            stage.employmentID = job.id
            stage.effectiveDate = ProfileRules.date(year, 1, 1)
            stage.salaryCents = 2_000_000
            container.mainContext.insert(stage)
        }
        try! container.mainContext.save()
        return container
    }()
    var body: some View {
        NavigationStack { CareerView(destination: .history) }
            .modelContainer(container)
            .environment(CareerClock())
            .environment(AppNavigation())
            .environment(\.locale, Locale(identifier: "zh_CN"))
    }
}
#endif
