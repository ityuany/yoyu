import SwiftUI
import SwiftData
import UIKit

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
                    } else { Text("保留未知月份，确认后再补充。").foregroundStyle(AppTheme.secondaryText) }
                }.listRowBackground(AppTheme.cardBackground)
                Section {
                    number("税前月薪", text: $salary, unit: "元/月")
                } header: { Text("薪资待遇") } footer: {
                    Text("留空表示未知，0 表示没有。")
                }.listRowBackground(AppTheme.cardBackground)
                Section {
                    TextField("调整原因（选填）", text: $reason)
                } footer: {
                    Text(stage == nil ? "新增阶段会保留原有薪资。未来月份的待遇在生效前不会用于当前薪资。" : "此操作修改已有记录，不会新增一次调薪。")
                }.listRowBackground(AppTheme.cardBackground)
                if let validation { Section { Text(validation).foregroundStyle(AppTheme.error) }.listRowBackground(AppTheme.cardBackground) }
                if stage != nil {
                    Section {
                        Button("删除薪资阶段", role: .destructive) { confirmingDeletion = true }
                    }.listRowBackground(AppTheme.cardBackground)
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
                Text(unit).foregroundStyle(AppTheme.secondaryText).fixedSize()
            }
        } label: { Text(title) }
    }
    private var validation: String? {
        for (name, value, max) in [("月薪", salary, ProfileRules.maximumMoneyCents)] {
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
        value.reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasDate && value.reason == "沿用原有待遇，生效月份待补充" { value.reason = "" }
        value.modifiedAt = Date()
        if let message = context.saveOrRollback() { error = message } else { dismiss() }
    }
}
