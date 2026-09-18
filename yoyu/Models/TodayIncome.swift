import Foundation

/// 按班次归属日分摊税前月薪；金额为估算，不代表银行入账。
enum TodayIncome {
    enum Status { case beforeWork, working, finished, rest }
    struct Snapshot {
        let day: Date
        let start: Date
        let end: Date
        let status: Status
        let dailyCents: Int64
        let earnedCents: Int64
        let monthCents: Int64?
        let progress: Double
        let completedWorkdays: Int
        let monthlyWorkdays: Int
        let missingHolidayYear: Bool
    }

    static func isWorkday(_ day: Date, job: Employment) -> Bool {
        HolidaySchedule.workday(day, workweek: Workweek(mask: job.workweekMask),
                                followsHolidays: job.followsHolidays, override: nil).isWorkday
    }

    static func shift(on day: Date, job: Employment) -> (start: Date, end: Date)? {
        let calendar = ProfileRules.calendar
        guard (0..<1440).contains(job.startMinutes), (0..<1440).contains(job.endMinutes),
              job.startMinutes != job.endMinutes,
              let start = calendar.date(byAdding: .minute, value: job.startMinutes, to: calendar.startOfDay(for: day)),
              let end = calendar.date(byAdding: .minute,
                                      value: job.endMinutes + (job.endMinutes < job.startMinutes ? 1440 : 0),
                                      to: calendar.startOfDay(for: day)) else { return nil }
        return (start, end)
    }

    static func snapshot(job: Employment, stages: [SalaryStage], now: Date) -> Snapshot? {
        let calendar = ProfileRules.calendar
        guard let hireDate = job.start else { return nil }
        let hire = calendar.startOfDay(for: hireDate)
        var day = calendar.startOfDay(for: now)
        // 零点以后仍在上一班的工作时段时，继续该班次，不清零。
        if job.endMinutes < job.startMinutes,
           let previous = calendar.date(byAdding: .day, value: -1, to: day), previous >= hire,
           isWorkday(previous, job: job), let previousShift = shift(on: previous, job: job),
           now < previousShift.end {
            day = previous
        }
        guard day >= hire, day <= (job.end.map({ calendar.startOfDay(for: $0) }) ?? .distantFuture),
              let shift = shift(on: day, job: job),
              let month = calendar.dateInterval(of: .month, for: day) else { return nil }
        let ordered = CareerRules.stages(stages, for: job)
        // 无生效日期或同日阶段冲突时，引导补全，避免把未知薪资套用到所有日期。
        guard !ordered.contains(where: { $0.effectiveDate == nil }) else { return nil }
        let dates = ordered.map { calendar.startOfDay(for: $0.effectiveDate!) }
        guard Set(dates).count == dates.count else { return nil }
        func salary(on date: Date) -> Int64? {
            guard let stage = ordered.first(where: { calendar.startOfDay(for: $0.effectiveDate!) <= date }),
                  let cents = stage.salaryCents, cents >= 0 else { return nil }
            return cents
        }
        guard let currentSalary = salary(on: day) else { return nil }
        var workdays = 0
        var cursor = month.start
        while cursor < month.end {
            if isWorkday(cursor, job: job) { workdays += 1 }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        let workingDay = isWorkday(day, job: job)
        let status: Status = !workingDay ? .rest : now < shift.start ? .beforeWork : now >= shift.end ? .finished : .working
        let progress = workingDay ? min(1, max(0, now.timeIntervalSince(shift.start) / shift.end.timeIntervalSince(shift.start))) : 0
        let daily = workingDay && workdays > 0 ? Decimal(currentSalary) / Decimal(workdays) : 0
        var monthTotal = Decimal.zero
        var complete = true
        var completedDays = 0
        cursor = max(month.start, hire)
        while cursor <= day {
            if isWorkday(cursor, job: job), workdays > 0 {
                if let interval = self.shift(on: cursor, job: job), now >= interval.end { completedDays += 1 }
                if let amount = salary(on: cursor), let interval = self.shift(on: cursor, job: job) {
                    let fraction = min(1, max(0, now.timeIntervalSince(interval.start) / interval.end.timeIntervalSince(interval.start)))
                    monthTotal += Decimal(amount) / Decimal(workdays) * Decimal(fraction)
                } else { complete = false }
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        guard let dailyCents = cents(daily), let earned = cents(daily * Decimal(progress)) else { return nil }
        return Snapshot(day: day, start: shift.start, end: shift.end, status: status,
                        dailyCents: dailyCents, earnedCents: earned,
                        monthCents: complete ? cents(monthTotal) : nil, progress: progress,
                        completedWorkdays: completedDays, monthlyWorkdays: workdays,
                        missingHolidayYear: job.followsHolidays && calendar.component(.year, from: day) != HolidaySchedule.supportedYear)
    }

    struct NextShift {
        let start: Date
        let dailyCents: Int64?
        let missingHolidayYear: Bool
    }

    /// 搜索未来一年，跨月使用下一班当月的工作天数与生效薪资。
    static func nextShift(job: Employment, stages: [SalaryStage], after date: Date) -> NextShift? {
        let calendar = ProfileRules.calendar
        var day = calendar.startOfDay(for: date)
        for _ in 0..<366 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = next
            if let end = job.end, day > calendar.startOfDay(for: end) { return nil }
            if let hire = job.start, day < calendar.startOfDay(for: hire) { continue }
            if isWorkday(day, job: job), let interval = shift(on: day, job: job) {
                return NextShift(start: interval.start,
                                 dailyCents: snapshot(job: job, stages: stages, now: interval.start)?.dailyCents,
                                 missingHolidayYear: job.followsHolidays && calendar.component(.year, from: day) != HolidaySchedule.supportedYear)
            }
        }
        return nil
    }

    private static func cents(_ value: Decimal) -> Int64? {
        var original = value
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &original, 0, .plain)
        guard rounded >= 0, rounded <= Decimal(Int64.max) else { return nil }
        return NSDecimalNumber(decimal: rounded).int64Value
    }
}
