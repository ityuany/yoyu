import SwiftUI
import SwiftData

struct EmploymentWorkDetail: View {
    let job: Employment
    @Environment(CareerClock.self) private var clock
    @Query private var stages: [SalaryStage]
    @State private var editing = false

    var body: some View {
        List {
            Section("工作安排") {
                let week = Workweek(mask: job.workweekMask)
                let days = Weekday.displayOrder.filter { week.contains($0) }.map(\.name)
                LabeledContent("工作日", value: days.isEmpty ? "每周休息" : days.joined(separator: "、"))
                LabeledContent("上班时间", value: ProfileRules.timeLabel(job.startMinutes))
                LabeledContent("下班时间", value: "\(job.endMinutes < job.startMinutes ? "次日 " : "")\(ProfileRules.timeLabel(job.endMinutes))")
                LabeledContent("遵循法定节假日及调休", value: job.followsHolidays ? "已开启" : "已关闭")
                if let summary = CareerRules.workSummary(stages, for: job, on: clock.now) {
                    LabeledContent("累计应工作天数", value: "\(summary.days.formatted()) 天")
                    LabeledContent("平均日薪（税前估算）", value: summary.averageDailyCents.map { ProfileRules.money($0) } ?? (summary.days == 0 ? "暂无应工作日" : "薪资资料待补全"))
                    Text("按任职期间累计税前工资 ÷ 同期应工作天数计算，包含入离职当天，当前任职统计至今天；暂不含年终奖。")
                        .font(.caption).foregroundStyle(.secondary)
                    if summary.missingHolidayYears {
                        Text("部分年份节假日资料未收录，对应天数按每周工作日估算。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button("编辑工作安排") { editing = true }
            }
        }
        .neutralPageBackground()
        .navigationTitle("工作安排")
        .sheet(isPresented: $editing) { EmploymentWorkEditor(job: job) }
    }
}
