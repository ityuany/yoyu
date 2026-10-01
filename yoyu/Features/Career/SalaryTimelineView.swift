import SwiftUI
import SwiftData

struct SalaryTimelineView: View {
    let job: Employment
    @Environment(CareerClock.self) private var clock
    @Query private var stages: [SalaryStage]
    @State private var adding = false
    @State private var editing: SalaryStage?

    private var ordered: [SalaryStage] { CareerRules.stages(stages, for: job) }
    private var current: SalaryStage? { CareerRules.salary(stages, for: job, on: clock.now) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    Text(job.isCurrent(on: clock.now) ? "当前税前月薪" : "离职时税前月薪")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(ProfileRules.money(current?.salaryCents))
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    if let date = current?.effectiveDate {
                        Text("\(CareerRules.monthLabel(date)) 起生效")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            if ordered.isEmpty {
                ContentUnavailableView("尚无薪资阶段", systemImage: "calendar", description: Text("点右上角添加入职月薪或一次调薪。"))
            } else {
                Section("调薪时间轴") {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, stage in
                        let previous = index + 1 < ordered.count ? ordered[index + 1] : nil
                        CompensationTimelineRow(
                            date: stage.effectiveDate.map(CareerRules.monthLabel) ?? "月份待补充",
                            amount: ProfileRules.money(stage.salaryCents),
                            trend: EmploymentSalaryTrend(current: stage.salaryCents, previous: previous?.salaryCents),
                            isFirst: index == 0, isLast: index == ordered.count - 1,
                            note: stage.effectiveDate.map { $0 > clock.now ? "待生效" : "" } ?? "待补日期"
                        ) { editing = stage }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .neutralPageBackground()
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .navigationTitle("薪资变化")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("新增薪资阶段", systemImage: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $adding) { SalaryEditor(job: job, stage: nil, previous: current) }
        .sheet(item: $editing) { SalaryEditor(job: job, stage: $0, previous: nil) }
    }
}
