import SwiftUI
import SwiftData
import UIKit

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
                }.listRowBackground(AppTheme.cardBackground)
                Section {
                    Toggle("遵循法定节假日及调休", isOn: $followsHolidays)
                } footer: {
                    Text("开启后，放假日不计为工作日，调休补班日计为工作日。当前收录 2026 年安排，其他年份按每周工作日估算。")
                }.listRowBackground(AppTheme.cardBackground)
                Section("工作时间") {
                    DatePicker("上班时间", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("下班时间", selection: $end, displayedComponents: .hourAndMinute)
                    if minutes(end) < minutes(start) { Text("下班时间为次日").foregroundStyle(AppTheme.secondaryText) }
                    if minutes(end) == minutes(start) { Text("上下班时间不能相同。").foregroundStyle(AppTheme.error) }
                }.listRowBackground(AppTheme.cardBackground)
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
