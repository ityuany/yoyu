import Foundation

/// Presentation follows the income snapshot's shift date and actual work status.
/// Calendar labels are supplementary; they never change income calculations.
struct TodayMood {
    enum Kind: Equatable { case work, weekend, rest, holiday, makeup }
    let kind: Kind
    let holidayName: String?

    init(day: Date, isRest: Bool, followsHolidays: Bool) {
        let official = HolidaySchedule.officialDay(day)
        holidayName = official.flatMap { $0.isWorkday ? nil : $0.reason.replacingOccurrences(of: "放假", with: "") }
        if isRest {
            if holidayName != nil {
                kind = .holiday
            } else {
                let weekday = Weekday(day)
                kind = weekday == .saturday || weekday == .sunday ? .weekend : .rest
            }
        } else {
            kind = followsHolidays && official?.isWorkday == true ? .makeup : .work
        }
    }

    var label: String {
        switch kind {
        case .work: holidayName.map { "\($0) · 按安排上班" } ?? "工作日"
        case .weekend: "周末"
        case .rest: "休息日"
        case .holiday: holidayName ?? "节假日"
        case .makeup: "补班日"
        }
    }

    var restTitle: String {
        switch holidayName {
        case "春节": "把时间留给团圆"
        case "中秋节": "月圆，人也从容"
        case "清明节": "风起时，去看看春天"
        case "端午节": "悠悠夏日，慢慢过"
        case "元旦": "新的一年，从容开始"
        default: kind == .holiday ? "把时间交给海风" : "给自己留一点时间"
        }
    }

    var subtitle: String {
        switch kind {
        case .work: "每一份积累，都看得见。"
        case .makeup: "今天补班，按自己的节奏来。"
        case .weekend, .rest: "散散步，或者什么也不做。"
        case .holiday:
            holidayName == "清明节" ? "让思念与春风，一起停留。" : "今天，慢一点也很好。"
        }
    }
}
