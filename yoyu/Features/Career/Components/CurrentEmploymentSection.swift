import SwiftUI
import SwiftData

struct CurrentEmploymentSection: View {
    @Query private var jobs: [Employment]
    @Environment(CareerClock.self) private var clock
    @Query private var stages: [SalaryStage]
    var body: some View {
        Section("当前企业") {
            if let job = CareerRules.current(jobs, on: clock.now) {
                LabeledContent("企业名称", value: job.displayName)
                LabeledContent("入职月份", value: CareerRules.employmentMonthLabel(job.start))
                LabeledContent("当前税前月薪", value: ProfileRules.money(CareerRules.salary(stages, for: job, on: clock.now)?.salaryCents))
                NavigationLink("查看任职详情", value: CareerDestination.employment(job.id))
            } else {
                Text(jobs.isEmpty ? "待完善" : CareerRules.employments(jobs).filter { $0.isCurrent(on: clock.now) }.count > 1 ? "多段任职未结束，请完善履历" : "暂无当前任职").foregroundStyle(.secondary)
                NavigationLink("管理企业履历", value: CareerDestination.history)
            }
        }
    }
}
