import Foundation

struct Holiday: Identifiable {
    /// 名称。
    let name: String
    /// 所属月份。
    let month: Int
    /// 统计起始日期。
    let firstDay: Int
    /// 统计结束日期。
    let lastDay: Int
    /// 是否为调休补班。
    let makeup: [(month: Int, day: Int)]
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String { name }
    /// 节假日包含起止两天，所以天数需要额外加 1。
    /// 天数。
    var days: Int { lastDay - firstDay + 1 }
    /// 时间范围展示文字。
    var rangeLabel: String { "\(month) 月 \(firstDay)—\(lastDay) 日" }
}

enum HolidaySchedule {
    /// 默认资料的来源网址。
    static let sourceURL = URL(string: "https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm")!
    /// 已内置节假日资料的年份。
    static let supportedYear = 2026
    /// 内置节假日与调休安排。
    static let holidays: [Holiday] = [
        Holiday(name: "元旦", month: 1, firstDay: 1, lastDay: 3, makeup: [(1, 4)]),
        Holiday(name: "春节", month: 2, firstDay: 15, lastDay: 23, makeup: [(2, 14), (2, 28)]),
        Holiday(name: "清明节", month: 4, firstDay: 4, lastDay: 6, makeup: []),
        Holiday(name: "劳动节", month: 5, firstDay: 1, lastDay: 5, makeup: [(5, 9)]),
        Holiday(name: "端午节", month: 6, firstDay: 19, lastDay: 21, makeup: []),
        Holiday(name: "中秋节", month: 9, firstDay: 25, lastDay: 27, makeup: []),
        Holiday(name: "国庆节", month: 10, firstDay: 1, lastDay: 7, makeup: [(9, 20), (10, 10)])
    ]

    /// 查询内置官方安排：补班优先返回上班，假期区间返回休息；非收录日期返回 `nil`。
    static func officialDay(_ date: Date) -> (isWorkday: Bool, reason: String)? {
        let parts = ProfileRules.calendar.dateComponents([.year, .month, .day], from: date)
        guard parts.year == supportedYear, let month = parts.month, let day = parts.day else { return nil }
        for holiday in holidays {
            if holiday.makeup.contains(where: { $0.month == month && $0.day == day }) {
                return (true, "\(holiday.name)调休补班")
            }
            if month == holiday.month && (holiday.firstDay...holiday.lastDay).contains(day) {
                return (false, "\(holiday.name)放假")
            }
        }
        return nil
    }

    /// 按“个人调整 > 官方调休 > 常规周安排”的优先级计算某一天是否上班。
    static func workday(_ date: Date, workweek: Workweek, followsHolidays: Bool, override: Bool?) -> (isWorkday: Bool, reason: String) {
        if let override { return (override, "个人调整") }
        if followsHolidays, let official = officialDay(date) { return official }
        let isWorkday = workweek.contains(Weekday(date))
        let unknown = followsHolidays && ProfileRules.calendar.component(.year, from: date) != supportedYear
        return (isWorkday, unknown ? "按常规安排估算，未包含该年节假日及调休" : "每周常规安排")
    }
}
