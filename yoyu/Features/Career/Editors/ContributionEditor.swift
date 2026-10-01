import SwiftUI
import SwiftData
import UIKit

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
                }
                }
                if kind == .housing {
                Section("公积金") {
                    number("缴纳基数", text: $housingBase, unit: "元/月")
                    number("个人比例", text: $housingRate, unit: "%")
                }
                }
                Section {} footer: {
                    Text("从生效月份起按这组基数和比例自动累计，直到下一次调整或任职结束。")
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
            } else {
                record.housingBaseCents = nil
                record.housingBasisPoints = nil
            }
            record.modifiedAt = Date()
        }
        value.employmentID = job.id
        value.effectiveMonth = effectiveMonth
        if kind == .pension {
            value.pensionBaseCents = ProfileRules.scaledValue(pensionBase)
            value.pensionBasisPoints = ProfileRules.scaledValue(pensionRate, maximum: ProfileRules.maximumPercentBasisPoints)
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
