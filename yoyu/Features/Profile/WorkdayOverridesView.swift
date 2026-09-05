import SwiftUI
import SwiftData

struct WorkdayOverridesView: View {
    @Query(sort: \WorkdayOverride.modifiedAt, order: .reverse) private var overrides: [WorkdayOverride]
    let workweek: Workweek
    let followsHolidays: Bool
    @Environment(\.modelContext) private var context
    @State private var date = Date()
    @State private var choice = "默认"
    @State private var errorMessage: String?

    private var dateKey: String { ProfileRules.dateKey(date) }
    private var selectedOverride: WorkdayOverride? { overrides.first { $0.dateKey == dateKey } }
    private var result: (isWorkday: Bool, reason: String) {
        HolidaySchedule.workday(date, workweek: workweek,
                                followsHolidays: followsHolidays,
                                override: selectedOverride?.isWorkday)
    }
    private var uniqueOverrides: [WorkdayOverride] {
        var seen: Set<String> = []
        return overrides.filter { seen.insert($0.dateKey).inserted }.sorted { $0.dateKey < $1.dateKey }
    }

    var body: some View {
        Form {
            Section {
                DatePicker("选择日期", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.calendar, ProfileRules.calendar)
                    .environment(\.timeZone, ProfileRules.calendar.timeZone)
                LabeledContent("当前安排", value: result.isWorkday ? "上班" : "休息")
                Text(result.reason).font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Picker("调整为", selection: $choice) {
                    Text("默认").tag("默认")
                    Text("上班").tag("上班")
                    Text("休息").tag("休息")
                }
                .pickerStyle(.segmented)
                Button("保存这一天的安排", action: save)
            } footer: { Text("选择“默认”可移除个人调整，恢复官方调休或常规工作日安排。") }
            Section("已调整日期") {
                if uniqueOverrides.isEmpty {
                    Text("暂无个人调整").foregroundStyle(.secondary)
                }
                ForEach(uniqueOverrides) { item in
                    Button {
                        let components = item.dateKey.split(separator: "-").compactMap { Int($0) }
                        if components.count == 3 { date = ProfileRules.date(components[0], components[1], components[2]) }
                    } label: {
                        LabeledContent(item.dateKey, value: item.isWorkday ? "上班" : "休息")
                    }
                }
            }
        }
        .navigationTitle("特殊日期调整")
        .onAppear(perform: loadSelection)
        .onChange(of: dateKey) { _, _ in loadSelection() }
        .saveErrorAlert($errorMessage)
    }

    private func loadSelection() {
        choice = selectedOverride.map { $0.isWorkday ? "上班" : "休息" } ?? "默认"
    }
    private func save() {
        // Remove all matching rows, including any independently created on another device.
        for item in overrides where item.dateKey == dateKey { context.delete(item) }
        if choice != "默认" { context.insert(WorkdayOverride(dateKey: dateKey, isWorkday: choice == "上班")) }
        errorMessage = context.saveOrRollback()
    }
}
