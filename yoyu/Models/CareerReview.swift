import Foundation

enum CareerReview {
    struct Tenure: Identifiable {
        let id: String
        let name: String
        let start: Date
        let end: Date // Exclusive end, including the last employment day.
        var days: Int { ProfileRules.calendar.dateComponents([.day], from: start, to: end).day ?? 0 }
    }
    struct Pay: Identifiable {
        let id: String
        let jobID: String
        let name: String
        let start: Date
        let end: Date
        let cents: Int64
        let previousCents: Int64?
    }
    struct Summary {
        let tenures: [Tenure]
        let pay: [Pay]
        let totalDays: Int
        let incompleteJobs: Int

        /// Compound annual growth of recorded monthly pay, including calendar gaps.
        /// End dates are exclusive; use the final covered day, not a future boundary.
        var annualizedSalaryGrowth: Double? {
            guard let firstDate = pay.map(\.start).min(),
                  let lastEnd = pay.map(\.end).max(),
                  let lastDate = ProfileRules.calendar.date(byAdding: .day, value: -1, to: lastEnd) else { return nil }
            let first = pay.filter { $0.start <= firstDate && firstDate < $0.end }
            let last = pay.filter { $0.start <= lastDate && lastDate < $0.end }
            guard first.count == 1, last.count == 1,
                  let initial = first.first?.cents, initial > 0,
                  let final = last.first?.cents, final >= 0,
                  let anniversary = ProfileRules.calendar.date(byAdding: .year, value: 1, to: firstDate),
                  lastDate >= anniversary else { return nil }
            let days = ProfileRules.calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
            guard days > 0 else { return nil }
            let growth = pow(Double(final) / Double(initial), 365.2425 / Double(days)) - 1
            return growth.isFinite ? growth : nil
        }
    }
    static func summary(jobs: [Employment], stages: [SalaryStage], now: Date) -> Summary {
        let calendar = ProfileRules.calendar
        let today = calendar.startOfDay(for: now)
        var tenures: [Tenure] = []
        var pay: [Pay] = []
        var incomplete = 0
        for job in CareerRules.employments(jobs) {
            guard let date = job.start else { incomplete += 1; continue }
            let start = calendar.startOfDay(for: date)
            let last = calendar.startOfDay(for: min(job.end ?? now, now))
            guard start <= last, start <= today,
                  let end = calendar.date(byAdding: .day, value: 1, to: last) else { incomplete += 1; continue }
            tenures.append(Tenure(id: job.id, name: job.displayName, start: start, end: end))
            let ordered = CareerRules.stages(stages, for: job)
            let dated = ordered.compactMap { stage -> (Date, SalaryStage)? in
                guard let date = stage.effectiveDate else { return nil }
                return (calendar.startOfDay(for: date), stage)
            }.filter { $0.0 < end }.sorted { $0.0 < $1.0 }
            let groups = Dictionary(grouping: dated, by: { $0.0 })
            let dates = groups.keys.sorted()
            var missing = ordered.contains { $0.effectiveDate == nil }
            var covered = start
            var previous: Int64?
            for (index, date) in dates.enumerated() {
                let finish = index + 1 < dates.count ? min(dates[index + 1], end) : end
                let begin = max(date, start)
                guard finish > begin else { continue }
                guard let group = groups[date], group.count == 1,
                      let cents = group[0].1.salaryCents, cents >= 0 else {
                    missing = true; previous = nil; continue
                }
                if begin > covered { missing = true; previous = nil }
                pay.append(Pay(id: group[0].1.id, jobID: job.id, name: job.displayName,
                               start: begin, end: finish, cents: cents, previousCents: previous))
                covered = finish; previous = cents
            }
            if covered < end { missing = true }
            if missing { incomplete += 1 }
        }
        let sorted = tenures.sorted { $0.start < $1.start }
        var total = 0
        var cursor: Date?
        for tenure in sorted {
            let start = max(tenure.start, cursor ?? tenure.start)
            if tenure.end > start {
                total += calendar.dateComponents([.day], from: start, to: tenure.end).day ?? 0
            }
            cursor = max(cursor ?? tenure.end, tenure.end)
        }
        return Summary(tenures: sorted, pay: pay.sorted { $0.start < $1.start }, totalDays: total, incompleteJobs: incomplete)
    }
}
