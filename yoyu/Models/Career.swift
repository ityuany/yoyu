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
    var salaryPaymentDay: Int = 10
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
    // 旧版薪资阶段曾混存缴纳资料；保留字段以兼容已同步数据，不参与缴纳记录展示或计算。
    var pensionBasisPoints: Int64?
    var pensionBaseCents: Int64?
    var housingBasisPoints: Int64?
    var housingBaseCents: Int64?
    var bonusCents: Int64?
    var bonusMonth: Int = 12
    var reason: String = ""
    var modifiedAt: Date = Date()
    init() {}
}

@Model
final class ContributionStage {
    var id: String = UUID().uuidString
    var employmentID: String = ""
    var effectiveMonth: Date = Date()
    var pensionBaseCents: Int64?
    var pensionBasisPoints: Int64?
    var pensionVerifiedThroughMonth: Date?
    var pensionBaseEvidence: String?
    var housingBaseCents: Int64?
    var housingBasisPoints: Int64?
    var modifiedAt: Date = Date()
    init() {}
}

/// 参保证明原始逐月事实，用于核对实缴和基数来源；基数的业务时间线由 ContributionStage 表示。
@Model
final class SocialInsuranceMonth {
    var id: String = UUID().uuidString
    var employmentID: String = ""
    var month: Date = Date()
    var payerName: String = ""
    var pensionBaseCents: Int64?
    var pensionPersonalCents: Int64?
    var pensionBaseConverted: Bool = false
    var unemploymentBaseCents: Int64?
    var unemploymentPersonalCents: Int64?
    var injuryBaseCents: Int64?
    var remark: String = ""
    var sourceName: String = ""
    var sourceFingerprint: String = ""
    var modifiedAt: Date = Date()
    init() {}
}

enum ContributionKind: Hashable {
    case pension, housing

    var title: String { self == .pension ? "养老保险" : "住房公积金" }
    var shortTitle: String { self == .pension ? "养老金" : "公积金" }
    func base(_ record: ContributionStage) -> Int64? { self == .pension ? record.pensionBaseCents : record.housingBaseCents }
    func rate(_ record: ContributionStage) -> Int64? { self == .pension ? record.pensionBasisPoints : record.housingBasisPoints }
    func hasValues(_ record: ContributionStage) -> Bool { base(record) != nil || rate(record) != nil }
}

enum CareerRules {
    static func monthStart(_ date: Date) -> Date {
        ProfileRules.calendar.dateInterval(of: .month, for: date)!.start
    }

    static func monthEnd(_ date: Date) -> Date {
        ProfileRules.calendar.date(byAdding: .day, value: -1, to: ProfileRules.calendar.dateInterval(of: .month, for: date)!.end)!
    }

    /// 将既有任职记录直接整理为按整月计算的日期；重复执行不会改变已整理的数据。
    @MainActor static func normalizeEmploymentMonths(context: ModelContext) throws {
        let jobs = try context.fetch(FetchDescriptor<Employment>())
        var changed = false
        for job in jobs {
            var normalized = false
            if let start = job.start, start != monthStart(start) {
                job.start = monthStart(start)
                normalized = true
            }
            if let end = job.end, end != monthEnd(end) {
                job.end = monthEnd(end)
                normalized = true
            }
            if normalized { job.modifiedAt = Date(); changed = true }
        }
        if changed {
            do { try context.save() } catch { context.rollback(); throw error }
        }
    }

    /// 薪资从所选月份月初生效；既有具体日期直接归整到该月月初。
    @MainActor static func normalizeSalaryStageMonths(context: ModelContext) throws {
        let stages = try context.fetch(FetchDescriptor<SalaryStage>())
        var changed = false
        for stage in stages {
            var normalized = false
            if let date = stage.effectiveDate, date != monthStart(date) {
                stage.effectiveDate = monthStart(date)
                normalized = true
            }
            if stage.reason == "沿用原有待遇，生效日期待补充" {
                stage.reason = "沿用原有待遇，生效月份待补充"
                normalized = true
            }
            if normalized { stage.modifiedAt = Date(); changed = true }
        }
        if changed {
            do { try context.save() } catch { context.rollback(); throw error }
        }
    }

    /// 将证明里的基数变化点归入与手工调整相同的时间线，重复运行不会产生重复记录。
    @MainActor static func importPensionBaseChanges(context: ModelContext) throws {
        let months = try context.fetch(FetchDescriptor<SocialInsuranceMonth>())
        guard months.contains(where: { !$0.pensionBaseConverted }) else { return }
        let deduplicated = Dictionary(grouping: months, by: \.id).values
            .compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
        var stages = try context.fetch(FetchDescriptor<ContributionStage>())
        var changed = false
        for (employmentID, values) in Dictionary(grouping: deduplicated, by: \.employmentID) {
            let ordered = values.filter { $0.pensionBaseCents != nil }.sorted { $0.month < $1.month }
            var previousBase: Int64?
            for month in ordered {
                guard let base = month.pensionBaseCents else { continue }
                defer { previousBase = base }
                guard base != previousBase else { continue }
                let effectiveMonth = ProfileRules.calendar.dateInterval(of: .month, for: month.month)?.start ?? month.month
                if let existing = stages.first(where: {
                    $0.employmentID == employmentID &&
                    ProfileRules.calendar.isDate($0.effectiveMonth, equalTo: effectiveMonth, toGranularity: .month)
                }) {
                    // 人工记录优先；不覆盖用户已填的基数或比例。
                    if existing.pensionBaseCents == nil {
                        existing.pensionBaseCents = base
                        existing.pensionBaseEvidence = month.sourceName
                        existing.modifiedAt = Date()
                        changed = true
                    }
                    continue
                }
                let record = ContributionStage()
                let parts = ProfileRules.calendar.dateComponents([.year, .month], from: effectiveMonth)
                record.id = "pension-proof-\(employmentID)-\(parts.year ?? 0)-\(parts.month ?? 0)"
                record.employmentID = employmentID
                record.effectiveMonth = effectiveMonth
                record.pensionBaseCents = base
                record.pensionBaseEvidence = month.sourceName
                context.insert(record)
                stages.append(record)
                changed = true
            }
        }
        for month in months where !month.pensionBaseConverted {
            month.pensionBaseConverted = true
            changed = true
        }
        if changed { try context.save() }
    }

    /// 按生效月份查询基数；下一条生效前一直沿用，离职后不再继续。
    static func pensionBase(_ stages: [ContributionStage], for job: Employment, on month: Date) -> Int64? {
        guard let start = job.start,
              month >= (ProfileRules.calendar.dateInterval(of: .month, for: start)?.start ?? start),
              month <= (job.end ?? .distantFuture) else { return nil }
        return contributions(stages, for: job, kind: .pension)
            .first { $0.effectiveMonth <= month && $0.pensionBaseCents != nil }?.pensionBaseCents
    }

    /// 根据目标月份独立计算，不存在的发薪日取月末，避免短月使后续月份日期漂移。
    static func salaryPaymentDate(day: Int, inMonth date: Date) -> Date? {
        let calendar = ProfileRules.calendar
        guard (1...31).contains(day),
              let month = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: date) else { return nil }
        return calendar.date(byAdding: .day, value: min(day, days.count) - 1, to: month.start)
    }

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
    static func contributions(_ values: [ContributionStage], for employment: Employment) -> [ContributionStage] {
        Dictionary(grouping: values.filter { $0.employmentID == employment.id }, by: \.id).values
            .compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted { $0.effectiveMonth > $1.effectiveMonth }
    }
    static func contribution(_ values: [ContributionStage], for employment: Employment, on date: Date) -> ContributionStage? {
        contributions(values, for: employment).first { $0.effectiveMonth <= date }
    }
    static func contributionError(month: Date, id: String?, job: Employment, values: [ContributionStage]) -> String? {
        let calendar = ProfileRules.calendar
        guard let start = calendar.dateInterval(of: .month, for: month)?.start else { return "请选择生效月份。" }
        if start < (job.start.flatMap { calendar.dateInterval(of: .month, for: $0)?.start } ?? .distantPast) || start > (job.end ?? .distantFuture) {
            return "生效月份必须在任职期间内。"
        }
        if contributions(values, for: job).contains(where: { $0.id != id && calendar.isDate($0.effectiveMonth, equalTo: start, toGranularity: .month) }) {
            return "该月份已有缴纳记录，请修改已有记录。"
        }
        return nil
    }
    static func contributions(_ values: [ContributionStage], for employment: Employment, kind: ContributionKind) -> [ContributionStage] {
        contributions(values, for: employment).filter { kind.hasValues($0) }
    }
    static func contribution(_ values: [ContributionStage], for employment: Employment, kind: ContributionKind, on date: Date) -> ContributionStage? {
        contributions(values, for: employment, kind: kind).first { $0.effectiveMonth <= date }
    }
    static func contributionError(month: Date, id: String?, job: Employment, values: [ContributionStage], kind: ContributionKind) -> String? {
        let calendar = ProfileRules.calendar
        guard let start = calendar.dateInterval(of: .month, for: month)?.start else { return "请选择生效月份。" }
        if start < (job.start.flatMap { calendar.dateInterval(of: .month, for: $0)?.start } ?? .distantPast) || start > (job.end ?? .distantFuture) {
            return "生效月份必须在任职期间内。"
        }
        if contributions(values, for: job, kind: kind).contains(where: { $0.id != id && calendar.isDate($0.effectiveMonth, equalTo: start, toGranularity: .month) }) {
            return "该月份已有\(kind.title)记录，请修改已有记录。"
        }
        return nil
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
    static func employmentMonthLabel(_ date: Date?) -> String {
        guard let date else { return "月份待完善" }
        return monthLabel(date)
    }
    static func monthLabel(_ date: Date) -> String {
        let parts = ProfileRules.calendar.dateComponents([.year, .month], from: date)
        return "\(parts.year!) 年 \(parts.month!) 月"
    }
    static func employmentError(start: Date, end: Date?, id: String?, others: [Employment], stages: [SalaryStage], contributions: [ContributionStage] = []) -> String? {
        if monthStart(start) > monthStart(Date()) { return "入职月份不能晚于当前月份。" }
        if let end, monthStart(end) < monthStart(start) { return "离职月份不能早于入职月份。" }
        if let end, monthStart(end) > monthStart(Date()) { return "离职月份不能晚于当前月份。" }
        for other in employments(others) where other.id != id {
            if monthStart(start) <= (other.end.map(monthEnd) ?? .distantFuture) && (end.map(monthEnd) ?? .distantFuture) >= (other.start.map(monthStart) ?? .distantPast) {
                return "与「\(other.displayName)」的任职月份重叠；同一个月不能记录两家企业。"
            }
        }
        if stages.contains(where: { stage in
            guard stage.employmentID == id, let date = stage.effectiveDate else { return false }
            return date < start || date > (end ?? .distantFuture)
        }) { return "已有薪资阶段不在新的任职区间内，请先调整对应薪资记录。" }
        if contributions.contains(where: { record in
            guard record.employmentID == id else { return false }
            let startMonth = ProfileRules.calendar.dateInterval(of: .month, for: start)?.start ?? start
            return record.effectiveMonth < startMonth || record.effectiveMonth > (end ?? .distantFuture)
        }) { return "已有缴纳记录不在新的任职区间内，请先调整对应生效月份。" }
        return nil
    }
    static func stageError(date: Date, id: String?, job: Employment, stages: [SalaryStage]) -> String? {
        let month = monthStart(date)
        if month < (job.start.map(monthStart) ?? .distantPast) || month > (job.end.map(monthStart) ?? .distantFuture) { return "生效月份必须在任职区间内。" }
        if self.stages(stages, for: job).contains(where: { $0.id != id && $0.effectiveDate.map(monthStart) == month }) { return "该月份已有薪资阶段，请修改已有记录或选择其他月份。" }
        return nil
    }

    @MainActor static func migrate(context: ModelContext, profiles: [UserProfile], jobs: [Employment], stages: [SalaryStage]) throws {
        guard let source = profiles.max(by: { $0.updatedAt(for: .employment) < $1.updatedAt(for: .employment) }),
              !source.careerMigrated,
              source.hireDate != nil || source.salaryCents != nil || source.bonusCents != nil || profiles.contains(where: { $0.workUpdatedAt != nil }) else { return }
        let id = "legacy-\(source.createdAt.timeIntervalSince1970)"
        if !jobs.contains(where: { $0.id == id }) {
            let job = Employment()
            job.id = id
            job.start = source.hireDate.map(monthStart)
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
            stage.bonusCents = source.bonusCents
            stage.bonusMonth = source.bonusMonth
            stage.reason = "沿用原有待遇，生效月份待补充"
            context.insert(stage)
        }
        source.careerMigrated = true
        do { try context.save() } catch { context.rollback(); throw error }
    }
}
