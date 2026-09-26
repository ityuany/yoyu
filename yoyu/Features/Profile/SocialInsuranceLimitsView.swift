import SwiftUI
import SwiftData

struct SocialInsuranceLimitsView: View {
    @Query private var records: [SocialInsuranceLimit]
    @State private var showingNew = false
    @State private var editing: SocialInsuranceLimit?

    private var visibleRecords: [SocialInsuranceLimit] {
        return Dictionary(grouping: records, by: \.id).values
            .compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted {
                if $0.effectiveMonth != $1.effectiveMonth { return $0.effectiveMonth > $1.effectiveMonth }
                return $0.city.localizedStandardCompare($1.city) == .orderedAscending
            }
    }

    var body: some View {
        List {
            Section {
                Text("每条记录从生效月份开始沿用，直到下一条记录。金额为每月缴费基数的法定范围，不代表个人实际缴费基数。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(visibleRecords) { record in
                Button { editing = record } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(monthLabel(record.effectiveMonth))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(record.evidence.symbol) \(record.evidence.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 16) {
                            Text("下限 \(ProfileRules.money(record.lowerCents))")
                            Text("上限 \(ProfileRules.money(record.upperCents))")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("socialLimit.\(record.id)")
                .accessibilityHint("修改这条记录")
            }
        }
        .neutralPageBackground()
        .navigationTitle("基数范围")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("新增", systemImage: "plus") { showingNew = true }
                    .accessibilityIdentifier("socialLimit.add")
            }
        }
        .sheet(isPresented: $showingNew) {
            SocialInsuranceLimitEditor(record: nil, records: records)
        }
        .sheet(item: $editing) { record in
            SocialInsuranceLimitEditor(record: record, records: records)
        }
    }
}

private struct SocialInsuranceLimitEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let record: SocialInsuranceLimit?
    let records: [SocialInsuranceLimit]

    @State private var year: Int
    @State private var month: Int
    @State private var lower: String
    @State private var upper: String
    @State private var evidence: LimitEvidence
    @State private var draftYear: Int
    @State private var draftMonth: Int
    @State private var showingMonthPicker = false
    @State private var confirmingDeletion = false
    @State private var error: String?

    init(record: SocialInsuranceLimit?, records: [SocialInsuranceLimit]) {
        self.record = record
        self.records = records
        let components = ProfileRules.calendar.dateComponents([.year, .month], from: record?.effectiveMonth ?? Date())
        let year = components.year ?? 2026
        let month = components.month ?? 1
        _year = State(initialValue: year)
        _month = State(initialValue: month)
        _draftYear = State(initialValue: year)
        _draftMonth = State(initialValue: month)
        _lower = State(initialValue: ProfileRules.input(record?.lowerCents))
        _upper = State(initialValue: ProfileRules.input(record?.upperCents))
        _evidence = State(initialValue: record?.evidence ?? .unverified)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("适用范围") {
                    Button {
                        draftYear = year
                        draftMonth = month
                        showingMonthPicker = true
                    } label: {
                        HStack {
                            Text("生效年月").foregroundStyle(.primary)
                            Spacer()
                            Text("\(year) 年 \(month) 月").foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
                Section("月缴费基数") {
                    amountRow("下限", text: $lower, identifier: "socialLimit.lower")
                    amountRow("上限", text: $upper, identifier: "socialLimit.upper")
                }
                Section {
                    Picker("核实状态", selection: $evidence) {
                        ForEach(LimitEvidence.allCases) { value in
                            Text("\(value.symbol) \(value.title)").tag(value)
                        }
                    }
                }
                if let validation {
                    Section { Text(validation).foregroundStyle(.red) }
                }
                if record != nil {
                    Section {
                        Button("删除这条标准", role: .destructive) { confirmingDeletion = true }
                    }
                }
            }
            .neutralPageBackground()
            .navigationTitle(record == nil ? "新增社保上下限" : "修改社保上下限")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(validation != nil)
                }
            }
            .confirmationDialog("删除这条标准？", isPresented: $confirmingDeletion) {
                Button("删除", role: .destructive, action: delete)
                Button("取消", role: .cancel) { }
            }
            .sheet(isPresented: $showingMonthPicker) {
                NavigationStack {
                    HStack(spacing: 0) {
                        Picker("年", selection: $draftYear) {
                            ForEach(1990...2100, id: \.self) { Text("\($0) 年").tag($0) }
                        }
                        Picker("月", selection: $draftMonth) {
                            ForEach(1...12, id: \.self) { Text("\($0) 月").tag($0) }
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 200)
                    .navigationTitle("选择生效年月")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { showingMonthPicker = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") {
                                year = draftYear
                                month = draftMonth
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

    private func amountRow(_ title: String, text: Binding<String>, identifier: String) -> some View {
        LabeledContent(title) {
            HStack {
                TextField("金额", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier(identifier)
                Text("元/月").foregroundStyle(.secondary)
            }
        }
    }

    private var validation: String? {
        let normalizedCity = record?.city ?? "南京市"
        guard let lowerCents = ProfileRules.scaledValue(lower),
              let upperCents = ProfileRules.scaledValue(upper) else { return "请填写有效的上下限金额，最多两位小数。" }
        guard lowerCents > 0, upperCents >= lowerCents else { return "上限不能低于下限，且下限必须大于零。" }
        guard !records.contains(where: {
            $0.id != record?.id && $0.city.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedCity
                && ProfileRules.calendar.isDate($0.effectiveMonth, equalTo: ProfileRules.date(year, month, 1), toGranularity: .month)
        }) else { return "这个城市在该年月已有一条标准。" }
        return nil
    }

    private func save() {
        guard validation == nil,
              let lowerCents = ProfileRules.scaledValue(lower),
              let upperCents = ProfileRules.scaledValue(upper) else { return }
        let value = record ?? SocialInsuranceLimit()
        value.city = record?.city ?? "南京市"
        value.effectiveMonth = ProfileRules.date(year, month, 1)
        value.lowerCents = lowerCents
        value.upperCents = upperCents
        value.evidenceRaw = evidence.rawValue
        value.modifiedAt = Date()
        if record == nil { context.insert(value) }
        do { try context.save(); dismiss() }
        catch { self.error = error.localizedDescription }
    }

    private func delete() {
        guard let record else { return }
        for matching in records where matching.id == record.id { context.delete(matching) }
        do { try context.save(); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

private func monthLabel(_ date: Date) -> String {
    let components = ProfileRules.calendar.dateComponents([.year, .month], from: date)
    return "\(components.year ?? 0) 年 \(components.month ?? 0) 月"
}
