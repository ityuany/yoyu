import Foundation
import SwiftData

@Model
final class Employment {
    var id: String = UUID().uuidString
    var name: String = ""
    var start: Date?
    var end: Date?
    var modifiedAt: Date = Date()
    var followsHolidays: Bool = true
    var workweekMask: Int = 62
    var startMinutes: Int = 540
    var endMinutes: Int = 1080
    var severanceData: Data?
    init() {}
    var displayName: String { name.isEmpty ? "企业名称待完善" : name }
    var isCurrent: Bool { isCurrent(on: Date()) }
    func isCurrent(on date: Date) -> Bool { (start ?? .distantPast) <= date && end == nil }
}

@Model
final class SalaryStage {
    var id: String = UUID().uuidString
    var employmentID: String = ""
    var effectiveDate: Date?
    var salaryCents: Int64?
    var pensionBasisPoints: Int64?
    var housingBasisPoints: Int64?
    var bonusCents: Int64?
    var bonusMonth: Int = 12
    var reason: String = ""
    var modifiedAt: Date = Date()
    init() {}
}

enum CareerRules {
    @MainActor static func deleteStage(id: String, employmentID: String, context: ModelContext) throws {
        do {
            let matches = try context.fetch(FetchDescriptor<SalaryStage>()).filter {
                $0.id == id && $0.employmentID == employmentID
            }
            for stage in matches { context.delete(stage) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func tenureDays(for job: Employment, on date: Date) -> Int? {
        let calendar = ProfileRules.calendar
        guard let start = job.start else { return nil }
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: min(job.end ?? date, date))
        guard first <= last else { return nil }
        return calendar.dateComponents([.day], from: first, to: last).day.map { $0 + 1 }
    }

    /// 按月内自然日分摊各薪资阶段；包含首尾日，不含奖金及个人扣缴。
    /// 无日期、薪资缺口或同日冲突时不展示不完整的总额。
    static func estimatedSalaryCents(_ values: [SalaryStage], for job: Employment, on date: Date) -> Int64? {
        let calendar = ProfileRules.calendar
        guard let start = job.start, tenureDays(for: job, on: date) != nil else { return nil }
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: min(job.end ?? date, date))
        guard let limit = calendar.date(byAdding: .day, value: 1, to: last) else { return nil }
        let stages = self.stages(values, for: job)
        guard !stages.contains(where: { $0.effectiveDate == nil }) else { return nil }
        let dated = stages.map { (date: calendar.startOfDay(for: $0.effectiveDate!), salary: $0.salaryCents) }
            .filter { $0.date < limit }
            .sorted { $0.date < $1.date }
        guard Set(dated.map(\.date)).count == dated.count else { return nil }
        var total = Decimal.zero
        while cursor < limit {
            guard let stage = dated.last(where: { $0.date <= cursor }),
                  let salary = stage.salary, salary >= 0,
                  let month = calendar.dateInterval(of: .month, for: cursor),
                  let days = calendar.range(of: .day, in: .month, for: cursor)?.count else { return nil }
            let nextStage = dated.first(where: { $0.date > cursor })?.date ?? limit
            let end = min(limit, month.end, nextStage)
            let count = calendar.dateComponents([.day], from: cursor, to: end).day!
            total += Decimal(salary) * Decimal(count) / Decimal(days)
            cursor = end
        }
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &total, 0, .plain)
        guard rounded >= 0, rounded <= Decimal(Int64.max) else { return nil }
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    struct WorkSummary {
        let days: Int
        let missingHolidayYears: Bool
        let averageDailyCents: Int64?
    }

    static func workSummary(_ stages: [SalaryStage], for job: Employment, on date: Date) -> WorkSummary? {
        let calendar = ProfileRules.calendar
        guard let start = job.start, tenureDays(for: job, on: date) != nil else { return nil }
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: min(job.end ?? date, date))
        let week = Workweek(mask: job.workweekMask)
        var days = 0
        var missing = false
        while cursor <= last {
            if job.followsHolidays && calendar.component(.year, from: cursor) != HolidaySchedule.supportedYear {
                missing = true
            }
            if HolidaySchedule.workday(cursor, workweek: week, followsHolidays: job.followsHolidays, override: nil).isWorkday {
                days += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { return nil }
            cursor = next
        }
        var average: Int64?
        if days > 0, let income = estimatedSalaryCents(stages, for: job, on: date) {
            var value = Decimal(income) / Decimal(days)
            var rounded = Decimal.zero
            NSDecimalRound(&rounded, &value, 0, .plain)
            average = NSDecimalNumber(decimal: rounded).int64Value
        }
        return WorkSummary(days: days, missingHolidayYears: missing, averageDailyCents: average)
    }

    // CloudKit 不支持唯一约束。迁移使用稳定业务 ID，读取时归并不同设备导入的同一旧记录。
    static func employments(_ values: [Employment]) -> [Employment] {
        Dictionary(grouping: values, by: \.id).values.compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted { ($0.start ?? .distantPast) > ($1.start ?? .distantPast) }
    }
    static func stages(_ values: [SalaryStage], for employment: Employment) -> [SalaryStage] {
        Dictionary(grouping: values.filter { $0.employmentID == employment.id }, by: \.id).values
            .compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted { ($0.effectiveDate ?? .distantPast) > ($1.effectiveDate ?? .distantPast) }
    }
    static func current(_ jobs: [Employment], on date: Date = Date()) -> Employment? {
        let current = employments(jobs).filter { $0.isCurrent(on: date) }
        return current.count == 1 ? current.first : nil
    }
    static func salary(_ stages: [SalaryStage], for job: Employment, on date: Date = Date()) -> SalaryStage? {
        let cutoff = min(ProfileRules.calendar.startOfDay(for: date), job.end ?? .distantFuture)
        return self.stages(stages, for: job).first { ($0.effectiveDate ?? .distantPast) <= cutoff }
    }
    static func dateLabel(_ date: Date?) -> String {
        guard let date else { return "日期待完善" }
        let parts = ProfileRules.calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year!)年\(parts.month!)月\(parts.day!)日"
    }
    static func employmentError(start: Date, end: Date?, id: String?, others: [Employment], stages: [SalaryStage]) -> String? {
        if start > ProfileRules.calendar.startOfDay(for: Date()) { return "入职日期不能晚于今天。" }
        if let end, end < start { return "离职日期不能早于入职日期。" }
        if let end, end > ProfileRules.calendar.startOfDay(for: Date()) { return "离职日期不能晚于今天。" }
        for other in employments(others) where other.id != id {
            if start <= (other.end ?? .distantFuture) && (end ?? .distantFuture) >= (other.start ?? .distantPast) {
                return "与「\(other.displayName)」的任职区间重叠，请先完善该段经历的入离职日期。"
            }
        }
        if stages.contains(where: { stage in
            guard stage.employmentID == id, let date = stage.effectiveDate else { return false }
            return date < start || date > (end ?? .distantFuture)
        }) { return "已有薪资阶段不在新的任职区间内，请先调整对应薪资记录。" }
        return nil
    }
    static func stageError(date: Date, id: String?, job: Employment, stages: [SalaryStage]) -> String? {
        if date < (job.start ?? .distantPast) || date > (job.end ?? .distantFuture) { return "生效日期必须在任职区间内。" }
        if self.stages(stages, for: job).contains(where: { $0.id != id && $0.effectiveDate == date }) { return "该日期已有薪资阶段，请修改已有记录或选择其他日期。" }
        return nil
    }

    @MainActor static func migrate(context: ModelContext, profiles: [UserProfile], jobs: [Employment], stages: [SalaryStage]) throws {
        guard let source = profiles.max(by: { $0.updatedAt(for: .employment) < $1.updatedAt(for: .employment) }),
              !source.careerMigrated,
              source.hireDate != nil || source.salaryCents != nil || source.pensionBasisPoints != nil || source.housingBasisPoints != nil || source.bonusCents != nil || profiles.contains(where: { $0.workUpdatedAt != nil }) else { return }
        let id = "legacy-\(source.createdAt.timeIntervalSince1970)"
        if !jobs.contains(where: { $0.id == id }) {
            let job = Employment()
            job.id = id
            job.start = source.hireDate.map { ProfileRules.calendar.startOfDay(for: $0) }
            if let work = profiles.max(by: { $0.updatedAt(for: .work) < $1.updatedAt(for: .work) }) {
                job.workweekMask = work.workweekMask
                job.startMinutes = work.startMinutes
                job.endMinutes = work.endMinutes
            }
            context.insert(job)
        }
        if !stages.contains(where: { $0.id == id }) {
            let stage = SalaryStage()
            stage.id = id
            stage.employmentID = id
            stage.salaryCents = source.salaryCents
            stage.pensionBasisPoints = source.pensionBasisPoints
            stage.housingBasisPoints = source.housingBasisPoints
            stage.bonusCents = source.bonusCents
            stage.bonusMonth = source.bonusMonth
            stage.reason = "沿用原有待遇，生效日期待补充"
            context.insert(stage)
        }
        source.careerMigrated = true
        do { try context.save() } catch { context.rollback(); throw error }
    }
}
