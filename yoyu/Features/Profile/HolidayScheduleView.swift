import SwiftUI

struct HolidayScheduleView: View {
    private let year = ProfileRules.calendar.component(.year, from: Date())

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(String(year)) 年", systemImage: "calendar")
                        .font(.title2.weight(.bold))
                    Text("节假日调休安排").font(.headline)
                    Text("国务院办公厅公布 · 中国大陆")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            if year == HolidaySchedule.supportedYear {
                ForEach(HolidaySchedule.holidays) { holiday in
                    Section {
                        HStack(alignment: .firstTextBaseline) {
                            Text(holiday.name).font(.headline)
                            Spacer()
                            Text("共 \(holiday.days) 天").font(.subheadline).foregroundStyle(.secondary)
                        }
                        dayRow(badge: "休", text: holiday.rangeLabel, color: .green)
                        if holiday.makeup.isEmpty {
                            Text("无需补班").font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            ForEach(holiday.makeup.indices, id: \.self) { index in
                                let makeup = holiday.makeup[index]
                                let weekday = Weekday(ProfileRules.date(year, makeup.month, makeup.day))
                                dayRow(badge: "班", text: "\(makeup.month) 月 \(makeup.day) 日（\(weekday.name)）", color: .orange)
                            }
                        }
                    }
                }
                Section {
                    Link(destination: HolidaySchedule.sourceURL) {
                        Label("查看官方通知原文", systemImage: "arrow.up.right.square")
                    }
                } footer: {
                    Text("来源：国务院办公厅\n国办发明电〔2025〕7号 · 2025 年 11 月 4 日发布\n这里展示官方安排；公司或个人的变化请在工作安排中单独调整。")
                }
            } else {
                Section {
                    ContentUnavailableView("暂未收录 \(String(year)) 年安排", systemImage: "calendar.badge.exclamationmark", description: Text("当前内置 2026 年官方安排。请更新应用获取新年度数据；工作日暂按常规安排估算。"))
                    Link("前往中国政府网", destination: URL(string: "https://www.gov.cn/")!)
                }
            }
        }
        .navigationTitle("调休安排")
        #if os(iOS)
        .toolbar(.visible, for: .navigationBar)
        #endif
    }

    private func dayRow(badge: String, text: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(badge).font(.caption.weight(.bold))
                .padding(5).foregroundStyle(color)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                .accessibilityLabel(badge == "休" ? "放假" : "补班")
            Text(text).font(.subheadline)
        }
    }
}
