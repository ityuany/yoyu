import Foundation

@main struct TodayMoodTests {
    static func main() {
        func mood(_ day: String, rest: Bool, follows: Bool = true) -> TodayMood {
            TodayMood(day: ISO8601DateFormatter().date(from: day + "T12:00:00+08:00")!, isRest: rest, followsHolidays: follows)
        }
        precondition(mood("2026-09-18", rest: false).kind == .work)
        precondition(mood("2026-09-19", rest: true).kind == .weekend)
        precondition(mood("2026-09-19", rest: false).kind == .work)
        precondition(mood("2026-09-18", rest: true).kind == .rest)
        precondition(mood("2026-09-20", rest: false).kind == .makeup)
        precondition(mood("2026-09-20", rest: true).kind == .weekend)
        precondition(mood("2026-09-20", rest: false, follows: false).kind == .work)
        precondition(mood("2026-10-01", rest: true).kind == .holiday)
        precondition(mood("2026-10-01", rest: false, follows: false).kind == .work)
        precondition(mood("2026-10-01", rest: false, follows: false).label == "国庆节 · 按安排上班")
        precondition(mood("2026-09-25", rest: true).holidayName == "中秋节")
        precondition(mood("2026-04-05", rest: true).restTitle == "风起时，去看看春天")
        precondition(mood("2027-10-01", rest: true).kind == .rest)
        precondition(mood("2027-10-01", rest: true).holidayName == nil)
        print("Today mood: work schedules, weekends, holidays, makeup opt-out and unknown years passed")
    }
}
