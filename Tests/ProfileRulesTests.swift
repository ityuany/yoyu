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
        precondition(ProfileRules.scaledValue("100", maximum: 10000) == 10000)
        precondition(ProfileRules.scaledValue("100.01", maximum: 10000) == nil)
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
            precondition(HolidaySchedule.workday(date, weekMask: 62, followsHolidays: true, override: nil).isWorkday)
            precondition(!HolidaySchedule.workday(date, weekMask: 62, followsHolidays: false, override: nil).isWorkday)
            precondition(!HolidaySchedule.workday(date, weekMask: 62, followsHolidays: true, override: false).isWorkday)
        }
        for holiday in HolidaySchedule.holidays {
            for day in holiday.firstDay...holiday.lastDay {
                let date = ProfileRules.date(2026, holiday.month, day)
                precondition(HolidaySchedule.officialDay(date)?.isWorkday == false)
                precondition(HolidaySchedule.workday(date, weekMask: 127, followsHolidays: true, override: true).isWorkday)
            }
        }
        precondition(HolidaySchedule.officialDay(ProfileRules.date(2026, 2, 24)) == nil)
        precondition(HolidaySchedule.officialDay(ProfileRules.date(2027, 10, 1)) == nil)
        precondition(HolidaySchedule.workday(ProfileRules.date(2027, 10, 1), weekMask: 62, followsHolidays: true, override: nil).reason.contains("估算"))
        precondition(ProfileRules.dateKey(ProfileRules.date(2026, 9, 20)) == "2026-09-20")
        print("PASS: stock valuation/rounding/overflow, signed annual returns, retirement ages, fixed-point validation, holidays and override precedence")
    }
}
