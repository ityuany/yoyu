import SwiftUI
import SwiftData
import UIKit

private enum EmploymentMonthField: String, Identifiable {
    case start, end
    var id: String { rawValue }
}

struct EmploymentEditor: View {
    let job: Employment?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var jobs: [Employment]
    @Query private var stages: [SalaryStage]
    @Query private var contributions: [ContributionStage]
    @State private var salaryPaymentDay: Int
    @State private var name: String
    @State private var start: Date
    @State private var ended: Bool
    @State private var end: Date
    @State private var selectedMonthField: EmploymentMonthField?
    @State private var draftMonth = Date()
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
                    Button { draftMonth = start; selectedMonthField = .start } label: {
                        LabeledContent("入职月份", value: CareerRules.monthLabel(start))
                    }
                    .accessibilityIdentifier("employment.startMonth")
                    Picker("任职状态", selection: $ended) {
                        Text("在职").tag(false)
                        Text("已离职").tag(true)
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("employment.status")
                    if ended {
                        Button { draftMonth = end; selectedMonthField = .end } label: {
                            LabeledContent("离职月份", value: CareerRules.monthLabel(end))
                        }
                        .accessibilityIdentifier("employment.endMonth")
                    }
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
            .sheet(item: $selectedMonthField) { field in
                NavigationStack {
                    YearMonthWheel(selection: $draftMonth, maximumDate: Date())
                    .frame(height: 200)
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .navigationTitle(field == .start ? "选择入职月份" : "选择离职月份")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") { selectedMonthField = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("确定") {
                                if field == .start { start = draftMonth }
                                else { end = draftMonth }
                                selectedMonthField = nil
                            }
                        }
                    }
                }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
            }
        }
    }
    private var validation: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请填写企业名称。" }
        return CareerRules.employmentError(start: CareerRules.monthStart(start), end: ended ? CareerRules.monthEnd(end) : nil, id: job?.id, others: jobs, stages: stages, contributions: contributions)
    }
    private func save() {
        guard validation == nil else { return }
        let value = job ?? Employment()
        if job == nil { context.insert(value) }
        value.salaryPaymentDay = salaryPaymentDay
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.start = CareerRules.monthStart(start)
        value.end = ended ? CareerRules.monthEnd(end) : nil
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
    @State private var draftDate: Date = Date()
    @State private var showingMonthPicker = false
    @State private var hasDate: Bool
    @State private var salary: String
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
        _bonus = State(initialValue: ProfileRules.input(source?.bonusCents))
        _bonusMonth = State(initialValue: source?.bonusMonth ?? 12)
        _reason = State(initialValue: stage?.reason ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("生效时间") {
                    if stage != nil && stage?.effectiveDate == nil {
                        Toggle("补充生效月份", isOn: $hasDate)
                    }
                    if hasDate {
                        Button { draftDate = date; showingMonthPicker = true } label: {
                            LabeledContent("生效月份", value: CareerRules.monthLabel(date))
                        }
                        .accessibilityIdentifier("salary.effectiveMonth")
                    } else { Text("保留未知月份，确认后再补充。").foregroundStyle(.secondary) }
                }
                Section {
                    number("税前月薪", text: $salary, unit: "元/月")
                } header: { Text("薪资待遇") } footer: {
                    Text("留空表示未知，0 表示没有。")
                }
                Section("年终奖") {
                    number("奖金数额", text: $bonus, unit: "元")
                    Picker("发放月份", selection: $bonusMonth) { ForEach(1...12, id: \.self) { Text("\($0) 月").tag($0) } }
                }
                Section {
                    TextField("调整原因（选填）", text: $reason)
                } footer: {
                    Text(stage == nil ? "新增阶段会保留原有薪资。未来月份的待遇在生效前不会用于当前薪资。" : "此操作修改已有记录，不会新增一次调薪。")
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
            .sheet(isPresented: $showingMonthPicker) {
                NavigationStack {
                    YearMonthWheel(selection: $draftDate)
                        .frame(height: 200)
                        .padding(.horizontal)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .navigationTitle("选择生效月份")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("取消") { showingMonthPicker = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("确定") { date = draftDate; showingMonthPicker = false }
                            }
                        }
                }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
            }
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
        for (name, value, max) in [("月薪", salary, ProfileRules.maximumMoneyCents), ("奖金", bonus, ProfileRules.maximumMoneyCents)] {
            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ProfileRules.scaledValue(value, maximum: max) == nil {
                return "\(name)需为非负数，最多两位小数；比例不超过 100%，金额不超过 1000 亿元。"
            }
        }
        guard hasDate else { return nil }
        return CareerRules.stageError(date: CareerRules.monthStart(date), id: stage?.id, job: job, stages: stages)
    }
    private func save() {
        guard validation == nil else { return }
        let value = stage ?? SalaryStage()
        if stage == nil { context.insert(value) }
        value.employmentID = job.id
        value.effectiveDate = hasDate ? CareerRules.monthStart(date) : nil
        value.salaryCents = ProfileRules.scaledValue(salary)
        value.bonusCents = ProfileRules.scaledValue(bonus)
        value.bonusMonth = bonusMonth
        value.reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasDate && value.reason == "沿用原有待遇，生效月份待补充" { value.reason = "" }
        value.modifiedAt = Date()
        if let message = context.saveOrRollback() { error = message } else { dismiss() }
    }
}

private struct YearMonthWheel: UIViewRepresentable {
    @Binding var selection: Date
    var maximumDate: Date? = nil

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .yearAndMonth
        picker.preferredDatePickerStyle = .wheels
        picker.calendar = ProfileRules.calendar
        picker.locale = Locale(identifier: "zh_CN")
        picker.minimumDate = ProfileRules.calendar.date(from: DateComponents(year: 1900, month: 1, day: 1))
        picker.maximumDate = maximumDate ?? ProfileRules.calendar.date(from: DateComponents(year: 2100, month: 12, day: 1))
        picker.date = selection
        picker.addTarget(context.coordinator, action: #selector(Coordinator.monthChanged(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.selection = $selection
        let calendar = ProfileRules.calendar
        let shown = calendar.dateComponents([.year, .month], from: picker.date)
        let selected = calendar.dateComponents([.year, .month], from: selection)
        if shown.year != selected.year || shown.month != selected.month {
            picker.setDate(selection, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    final class Coordinator: NSObject {
        var selection: Binding<Date>

        init(selection: Binding<Date>) { self.selection = selection }

        @objc func monthChanged(_ picker: UIDatePicker) {
            let calendar = ProfileRules.calendar
            let components = calendar.dateComponents([.year, .month], from: picker.date)
            if let month = calendar.date(from: components) { selection.wrappedValue = month }
        }
    }
}

struct ContributionEditor: View {
    let job: Employment
    let record: ContributionStage?
    let kind: ContributionKind
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var records: [ContributionStage]
    @State private var effectiveMonth: Date
    @State private var draftMonth: Date
    @State private var showingMonthPicker = false
    @State private var verifiedThroughMonth: Date?
    @State private var draftVerifiedThroughMonth: Date = Date()
    @State private var showingVerifiedThroughPicker = false
    @State private var pensionBase: String
    @State private var pensionRate: String
    @State private var housingBase: String
    @State private var housingRate: String
    @State private var error: String?
    @State private var confirmingDeletion = false

    init(job: Employment, record: ContributionStage?, previous: ContributionStage?, kind: ContributionKind) {
        self.job = job
        self.record = record
        self.kind = kind
        let source = record ?? previous
        let initial = record?.effectiveMonth ?? job.end ?? Date()
        let normalizedMonth = ProfileRules.calendar.date(
            from: ProfileRules.calendar.dateComponents([.year, .month], from: initial)
        ) ?? initial
        _effectiveMonth = State(initialValue: normalizedMonth)
        _draftMonth = State(initialValue: normalizedMonth)
        _verifiedThroughMonth = State(initialValue: record?.pensionVerifiedThroughMonth)
        _pensionBase = State(initialValue: ProfileRules.input(source?.pensionBaseCents))
        _pensionRate = State(initialValue: ProfileRules.input(source?.pensionBasisPoints))
        _housingBase = State(initialValue: ProfileRules.input(source?.housingBaseCents))
        _housingRate = State(initialValue: ProfileRules.input(source?.housingBasisPoints))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        draftMonth = effectiveMonth
                        showingMonthPicker = true
                    } label: {
                        HStack {
                            Text("生效月份").foregroundStyle(.primary)
                            Spacer()
                            Text(effectiveMonthLabel)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityIdentifier("contribution.effectiveMonth")
                }
                if kind == .pension {
                Section("养老金") {
                    number("缴纳基数", text: $pensionBase, unit: "元/月")
                    number("个人比例", text: $pensionRate, unit: "%")
                    Button {
                        draftVerifiedThroughMonth = verifiedThroughMonth ?? effectiveMonth
                        showingVerifiedThroughPicker = true
                    } label: {
                        HStack {
                            Text("已核实沿用至").foregroundStyle(.primary)
                            Spacer()
                            Text(verifiedThroughMonth.map(CareerRules.monthLabel) ?? "未填写")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    if verifiedThroughMonth != nil {
                        Button("清除核实月份") { verifiedThroughMonth = nil }
                    }
                }
                }
                if kind == .housing {
                Section("公积金") {
                    number("缴纳基数", text: $housingBase, unit: "元/月")
                    number("个人比例", text: $housingRate, unit: "%")
                }
                }
                Section {} footer: {
                    Text("请按实际生效月份填写；“已核实沿用至”只表示确认过的月份，不自动推断之后的缴纳情况。")
                }
                if let validation { Section { Text(validation).foregroundStyle(.red) } }
                if record != nil {
                    Section { Button("删除\(kind.title)记录", role: .destructive) { confirmingDeletion = true } }
                }
            }
            .neutralPageBackground()
            .environment(\.calendar, ProfileRules.calendar)
            .navigationTitle(record == nil ? "新增\(kind.title)记录" : "修改\(kind.title)记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save).disabled(validation != nil) }
            }
            .confirmationDialog("删除这条\(kind.title)记录？", isPresented: $confirmingDeletion) {
                Button("删除", role: .destructive) { delete() }
                Button("取消", role: .cancel) { }
            }
            .sheet(isPresented: $showingMonthPicker) {
                NavigationStack {
                    YearMonthWheel(selection: $draftMonth)
                        .frame(height: 200)
                        .padding(.horizontal)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .navigationTitle("选择生效月份")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("取消") { showingMonthPicker = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") {
                                    effectiveMonth = draftMonth
                                    showingMonthPicker = false
                                }
                            }
                        }
                }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingVerifiedThroughPicker) {
                NavigationStack {
                    YearMonthWheel(selection: $draftVerifiedThroughMonth)
                        .frame(height: 200)
                        .padding(.horizontal)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .navigationTitle("选择核实月份")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("取消") { showingVerifiedThroughPicker = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") {
                                    verifiedThroughMonth = ProfileRules.calendar.date(
                                        from: ProfileRules.calendar.dateComponents([.year, .month], from: draftVerifiedThroughMonth)
                                    )
                                    showingVerifiedThroughPicker = false
                                }
                            }
                        }
                }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
            }
            .saveErrorAlert($error)
        }
    }
    private func number(_ title: String, text: Binding<String>, unit: String) -> some View {
        LabeledContent {
            HStack {
                TextField("待填写", text: text).multilineTextAlignment(.trailing).accessibilityLabel(title)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Text(unit).foregroundStyle(.secondary)
            }
        } label: { Text(title) }
    }
    private var validation: String? {
        let pensionFields = [("养老金基数", pensionBase, ProfileRules.maximumMoneyCents), ("养老金比例", pensionRate, ProfileRules.maximumPercentBasisPoints)]
        let housingFields = [("公积金基数", housingBase, ProfileRules.maximumMoneyCents), ("公积金比例", housingRate, ProfileRules.maximumPercentBasisPoints)]
        let fields = kind == .pension ? pensionFields : housingFields
        for (name, text, maximum) in fields {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ProfileRules.scaledValue(text, maximum: maximum) == nil {
                return "\(name)需为非负数，最多两位小数；比例不超过 100%，金额不超过 1000 亿元。"
            }
        }
        if kind == .pension && pensionBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pensionRate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请填写养老保险缴纳基数或个人比例。"
        }
        if kind == .housing && housingBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && housingRate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请填写住房公积金缴纳基数或个人比例。"
        }
        guard let selectedMonth else { return "请选择生效月份。" }
        if kind == .pension, let verifiedThroughMonth, verifiedThroughMonth < selectedMonth {
            return "核实月份不能早于生效月份。"
        }
        return CareerRules.contributionError(month: selectedMonth, id: record?.id, job: job, values: records, kind: kind)
    }
    private var selectedMonth: Date? {
        ProfileRules.calendar.date(from: ProfileRules.calendar.dateComponents([.year, .month], from: effectiveMonth))
    }
    private var effectiveMonthLabel: String {
        let components = ProfileRules.calendar.dateComponents([.year, .month], from: effectiveMonth)
        return "\(components.year ?? 0) 年 \(components.month ?? 0) 月"
    }
    private func save() {
        guard validation == nil, let effectiveMonth = selectedMonth else { return }
        let movingOneSide = record != nil && record!.effectiveMonth != effectiveMonth && (
            kind == .pension
                ? record!.housingBaseCents != nil || record!.housingBasisPoints != nil
                : record!.pensionBaseCents != nil || record!.pensionBasisPoints != nil
        )
        let value = movingOneSide ? ContributionStage() : record ?? ContributionStage()
        if record == nil || movingOneSide { context.insert(value) }
        if movingOneSide, let record {
            if kind == .pension {
                record.pensionBaseCents = nil
                record.pensionBasisPoints = nil
                record.pensionVerifiedThroughMonth = nil
                record.pensionBaseEvidence = nil
            } else {
                record.housingBaseCents = nil
                record.housingBasisPoints = nil
            }
            record.modifiedAt = Date()
        }
        value.employmentID = job.id
        value.effectiveMonth = effectiveMonth
        if kind == .pension {
            if record?.pensionBaseCents != ProfileRules.scaledValue(pensionBase) { value.pensionBaseEvidence = nil }
            value.pensionBaseCents = ProfileRules.scaledValue(pensionBase)
            value.pensionBasisPoints = ProfileRules.scaledValue(pensionRate, maximum: ProfileRules.maximumPercentBasisPoints)
            value.pensionVerifiedThroughMonth = verifiedThroughMonth
        }
        if kind == .housing {
            value.housingBaseCents = ProfileRules.scaledValue(housingBase)
            value.housingBasisPoints = ProfileRules.scaledValue(housingRate, maximum: ProfileRules.maximumPercentBasisPoints)
        }
        value.modifiedAt = Date()
        if let message = context.saveOrRollback() { error = message } else { dismiss() }
    }
    private func delete() {
        guard let record else { return }
        for value in records where value.id == record.id && value.employmentID == job.id {
            if kind == .pension {
                value.pensionBaseCents = nil
                value.pensionBasisPoints = nil
                value.pensionVerifiedThroughMonth = nil
                value.pensionBaseEvidence = nil
            } else {
                value.housingBaseCents = nil
                value.housingBasisPoints = nil
            }
            if (value.pensionBaseCents == nil && value.pensionBasisPoints == nil && value.housingBaseCents == nil && value.housingBasisPoints == nil) {
                context.delete(value)
            } else { value.modifiedAt = Date() }
        }
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
        let schema = Schema([Employment.self, SalaryStage.self, ContributionStage.self, SocialInsuranceMonth.self, StockHolding.self, UserProfile.self])
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
