import Foundation

@main
struct ProfileRulesTests {
    static func main() {
        precondition(ProfileRules.retirementAge(gender: "男") == 63)
        precondition(ProfileRules.retirementAge(gender: "女") == 58)
        precondition(ProfileRules.retirementAge(gender: "") == nil)
        precondition(ProfileRules.scaledValue("123.45") == 12345)
        precondition(ProfileRules.scaledValue("0") == 0)
        for value in ["", "-1", "1.001", "1e3", "nan", "999999999999999999"] {
            precondition(ProfileRules.scaledValue(value) == nil, value)
        }
        precondition(ProfileRules.scaledValue("100", maximum: ProfileRules.maximumPercentBasisPoints) == 10000)
        precondition(ProfileRules.scaledValue("100.01", maximum: ProfileRules.maximumPercentBasisPoints) == nil)
        precondition(ProfileRules.input(12345) == "123.45")
        precondition(ProfileRules.stockValue(sharesHundredths: 10000, priceCents: 1234) == 123400)
        precondition(ProfileRules.stockValue(sharesHundredths: 125, priceCents: 1234) == 1543)
        precondition(ProfileRules.stockValue(sharesHundredths: 1, priceCents: 49) == 0)
        precondition(ProfileRules.stockValue(sharesHundredths: 1, priceCents: 50) == 1)
        precondition(ProfileRules.stockValue(sharesHundredths: 0, priceCents: 1234) == 0)
        precondition(ProfileRules.stockValue(sharesHundredths: 10000, priceCents: nil) == nil)
        precondition(ProfileRules.stockValue(sharesHundredths: nil, priceCents: 1234) == nil)
        precondition(ProfileRules.stockValue(sharesHundredths: -1, priceCents: 1234) == nil)
        precondition(ProfileRules.stockValue(sharesHundredths: Int64.max, priceCents: Int64.max) == nil)
        precondition(ProfileRules.stockValue(sharesHundredths: 100, priceCents: ProfileRules.maximumMoneyCents) == ProfileRules.maximumMoneyCents)
        precondition(ProfileRules.stockValue(sharesHundredths: 101, priceCents: ProfileRules.maximumMoneyCents) == nil)
        // 月缴额 = 月薪 × 比例；覆盖正常比例、分级四舍五入、空值和上下限。
        precondition(ProfileRules.monthlyContribution(salaryCents: 1_000_000, rateBasisPoints: 800) == 80_000)
        precondition(ProfileRules.monthlyContribution(salaryCents: 1_000_000, rateBasisPoints: 1200) == 120_000)
        precondition(ProfileRules.monthlyContribution(salaryCents: 1, rateBasisPoints: 5000) == 1)
        precondition(ProfileRules.monthlyContribution(salaryCents: 1, rateBasisPoints: 4999) == 0)
        precondition(ProfileRules.monthlyContribution(salaryCents: 1_000_000, rateBasisPoints: 0) == 0)
        precondition(ProfileRules.monthlyContribution(salaryCents: nil, rateBasisPoints: 800) == nil)
        precondition(ProfileRules.monthlyContribution(salaryCents: 1_000_000, rateBasisPoints: nil) == nil)
        precondition(ProfileRules.monthlyContribution(salaryCents: -1, rateBasisPoints: 800) == nil)
        precondition(ProfileRules.monthlyContribution(salaryCents: Int64.max, rateBasisPoints: 800) == nil)
        precondition(ProfileRules.monthlyContribution(salaryCents: 1_000_000, rateBasisPoints: 10001) == nil)
        precondition(ProfileRules.monthlyContribution(salaryCents: ProfileRules.maximumMoneyCents, rateBasisPoints: 10000) == ProfileRules.maximumMoneyCents)
        precondition(ProfileRules.annualReturnRate("3.5") == 350)
        precondition(ProfileRules.annualReturnRate("-2.75") == -275)
        precondition(ProfileRules.annualReturnRate("0") == 0)
        precondition(ProfileRules.annualReturnRate("-100") == -10000)
        for value in ["", "- 1", "--1", "100.01", "-100.01", "3.555", "nan"] {
            precondition(ProfileRules.annualReturnRate(value) == nil, value)
        }
        precondition(HolidaySchedule.holidays.reduce(0) { $0 + $1.days } == 33)
        let makeupDays = [(1, 4), (2, 14), (2, 28), (5, 9), (9, 20), (10, 10)]
        for (month, day) in makeupDays {
            let date = ProfileRules.date(2026, month, day)
            precondition(HolidaySchedule.workday(date, workweek: .default, followsHolidays: true, override: nil).isWorkday)
            precondition(!HolidaySchedule.workday(date, workweek: .default, followsHolidays: false, override: nil).isWorkday)
            precondition(!HolidaySchedule.workday(date, workweek: .default, followsHolidays: true, override: false).isWorkday)
        }
        for holiday in HolidaySchedule.holidays {
            for day in holiday.firstDay...holiday.lastDay {
                let date = ProfileRules.date(2026, holiday.month, day)
                precondition(HolidaySchedule.officialDay(date)?.isWorkday == false)
                precondition(HolidaySchedule.workday(date, workweek: Workweek(mask: 127), followsHolidays: true, override: true).isWorkday)
            }
        }
        precondition(HolidaySchedule.officialDay(ProfileRules.date(2026, 2, 24)) == nil)
        precondition(HolidaySchedule.officialDay(ProfileRules.date(2027, 10, 1)) == nil)
        precondition(HolidaySchedule.workday(ProfileRules.date(2027, 10, 1), workweek: .default, followsHolidays: true, override: nil).reason.contains("估算"))
        precondition(ProfileRules.dateKey(ProfileRules.date(2026, 9, 20)) == "2026-09-20")
        // 2026-09-20 is a Sunday, 2026-09-21 a Monday.
        precondition(Weekday(ProfileRules.date(2026, 9, 20)) == .sunday)
        precondition(Weekday(ProfileRules.date(2026, 9, 21)) == .monday)
        precondition(Weekday.displayOrder.count == 7)
        precondition(Set(Weekday.displayOrder) == Set(Weekday.allCases))
        precondition(Weekday.displayOrder.first == .monday && Weekday.displayOrder.last == .sunday)
        precondition(Weekday.allCases.map(\.name) == ["周日", "周一", "周二", "周三", "周四", "周五", "周六"])
        precondition(Workweek.default.mask == 62)
        for weekday in [Weekday.monday, .tuesday, .wednesday, .thursday, .friday] {
            precondition(Workweek.default.contains(weekday), weekday.name)
        }
        precondition(!Workweek.default.contains(.saturday))
        precondition(!Workweek.default.contains(.sunday))
        var workweek = Workweek.default
        workweek.set(.saturday, isWorkday: true)
        precondition(workweek.contains(.saturday) && workweek.mask == 126)
        workweek.set(.saturday, isWorkday: true)
        precondition(workweek.mask == 126, "setting an existing workday must be idempotent")
        workweek.set(.monday, isWorkday: false)
        precondition(!workweek.contains(.monday) && workweek.mask == 124)
        workweek.set(.monday, isWorkday: false)
        precondition(workweek.mask == 124, "clearing a rest day must be idempotent")
        precondition(Workweek(mask: 0).mask == 0)
        for weekday in Weekday.allCases {
            precondition(!Workweek(mask: 0).contains(weekday), weekday.name)
            precondition(Workweek(mask: 127).contains(weekday), weekday.name)
            var single = Workweek(mask: 0)
            single.set(weekday, isWorkday: true)
            precondition(single.contains(weekday))
            precondition(Weekday.allCases.filter(single.contains) == [weekday], weekday.name)
        }
        print("PASS: stock valuation/rounding/overflow, signed annual returns, retirement ages, fixed-point validation, weekdays and workweek masks, holidays and override precedence")
    }
}
