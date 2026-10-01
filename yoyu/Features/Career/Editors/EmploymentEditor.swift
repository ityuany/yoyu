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
                }.listRowBackground(AppTheme.cardBackground)
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
                }.listRowBackground(AppTheme.cardBackground)
                Section {
                    Text("保存任职经历后，可在详情中录入薪资阶段和工作安排。")
                        .foregroundStyle(AppTheme.secondaryText)
                }.listRowBackground(AppTheme.cardBackground)
                if let validation { Section { Text(validation).foregroundStyle(AppTheme.error) }.listRowBackground(AppTheme.cardBackground) }
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
