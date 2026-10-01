import Foundation
import SwiftData

@Model
final class Employment {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 名称。
    var name: String = ""
    /// 开始日期。
    var start: Date?
    /// 结束日期，空值表示尚未结束。
    var end: Date?
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    /// 是否遵循法定节假日及调休。
    var followsHolidays: Bool = true
    /// 每周工作日的位掩码。
    var workweekMask: Int = 62
    /// 上班时间距零点的分钟数。
    var startMinutes: Int = 540
    /// 下班时间距零点的分钟数。
    var endMinutes: Int = 1080
    /// 每月发薪日，范围为 1 至 31。
    var salaryPaymentDay: Int = 10
    /// 旧版补偿配置 JSON，仅用于兼容读取和迁移，新保存不再写入。
    var severanceData: Data?
    /// 补偿配置是否已保存为独立字段。
    var hasStructuredSeverance: Bool = false
    /// 补偿方案的原始枚举值。
    var severancePlanRaw: String = "nPlusOne"
    /// 旧手动补偿工资基数，单位为分。
    var severanceBaseSalaryCents: Int64?
    /// 旧手动代通知金工资基数，单位为分。
    var severanceNoticeSalaryCents: Int64?
    /// 旧手动工龄，单位为百分之一年。
    var severanceTenureHundredths: Int64?
    /// 旧自定义补偿金额，单位为分。
    var severanceCustomAmountCents: Int64?
    /// 地区三倍社平月工资标准，单位为分。
    var severanceTripleAverageSalaryCents: Int64?
    init() {}
    /// 用于界面展示的名称。
    var displayName: String { name.isEmpty ? "企业名称待完善" : name }
    /// 是否为当前任职。
    var isCurrent: Bool { isCurrent(on: Date()) }
    func isCurrent(on date: Date) -> Bool { (start ?? .distantPast) <= date && end == nil }
}

@Model
final class SalaryStage {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 所属任职记录的业务标识。
    var employmentID: String = ""
    /// 薪资阶段生效日期，空值表示旧资料待核对。
    var effectiveDate: Date?
    /// 税前月薪，单位为分。
    var salaryCents: Int64?
    // 旧版薪资阶段曾混存缴纳资料；保留字段以兼容已同步数据，不参与缴纳记录展示或计算。
    /// 个人养老保险缴纳比例，单位为基点，100 基点等于 1%。
    var pensionBasisPoints: Int64?
    /// 养老保险缴纳基数，单位为分。
    var pensionBaseCents: Int64?
    /// 个人公积金缴纳比例，单位为基点，100 基点等于 1%。
    var housingBasisPoints: Int64?
    /// 公积金缴纳基数，单位为分。
    var housingBaseCents: Int64?
    // Read only by the one-time import into BonusPayment. Kept in the store schema
    // so an existing development database can be opened before that import runs.
    /// 旧年终奖金额，单位为分。
    var bonusCents: Int64?
    /// 旧年终奖发放月份。
    var bonusMonth: Int = 12
    /// 调整原因。
    var reason: String = ""
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    init() {}
}

@Model
final class BonusPayment {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 所属任职记录的业务标识。
    var employmentID: String = ""
    // Older salary stages never recorded which year a payment belonged to.
    // They remain visible for review, but do not enter totals until dated.
    /// 所属年份，空值表示旧记录尚未确认年份。
    var year: Int?
    /// 所属月份。
    var month: Int = 12
    /// 金额，单位为分。
    var amountCents: Int64?
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    init() {}
}

enum BonusRules {
    static func payments(_ values: [BonusPayment], for job: Employment) -> [BonusPayment] {
        Dictionary(grouping: values.filter { $0.employmentID == job.id }, by: \.id).values
            .compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted { ($0.year ?? Int.min, $0.month, $0.modifiedAt) > ($1.year ?? Int.min, $1.month, $1.modifiedAt) }
    }

    static func confirmed(_ values: [BonusPayment], for job: Employment) -> [BonusPayment] {
        payments(values, for: job).filter { $0.year != nil && $0.amountCents != nil }
    }

    static func total(_ values: [BonusPayment], for job: Employment) -> Int64? {
        let amounts = confirmed(values, for: job).compactMap(\.amountCents)
        guard !amounts.isEmpty else { return nil }
        return amounts.reduce(0, +)
    }

    @MainActor static func importLegacyStagePayments(context: ModelContext) throws {
        let stages = try context.fetch(FetchDescriptor<SalaryStage>())
        var existing = Set(try context.fetch(FetchDescriptor<BonusPayment>()).map(\.id))
        var changed = false
        for stage in stages {
            guard let amount = stage.bonusCents else { continue }
            let id = "salary-stage-bonus-\(stage.id)"
            if !existing.contains(id) {
                let payment = BonusPayment()
                payment.id = id
                payment.employmentID = stage.employmentID
                payment.month = stage.bonusMonth
                payment.amountCents = amount
                context.insert(payment)
                existing.insert(id)
            }
            stage.bonusCents = nil
            changed = true
        }
        guard changed else { return }
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

@Model
final class ContributionStage {
    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: String = UUID().uuidString
    /// 所属任职记录的业务标识。
    var employmentID: String = ""
    /// 生效月份，以月初日期表示。
    var effectiveMonth: Date = Date()
    /// 养老保险缴纳基数，单位为分。
    var pensionBaseCents: Int64?
    /// 个人养老保险缴纳比例，单位为基点，100 基点等于 1%。
    var pensionBasisPoints: Int64?
    /// 公积金缴纳基数，单位为分。
    var housingBaseCents: Int64?
    /// 个人公积金缴纳比例，单位为基点，100 基点等于 1%。
    var housingBasisPoints: Int64?
    /// 最近修改时间，用于归并同一业务记录的副本。
    var modifiedAt: Date = Date()
    init() {}
}

enum ContributionKind: Hashable {
    case pension, housing

    /// 展示标题。
    var title: String { self == .pension ? "养老保险" : "住房公积金" }
    /// 简短展示名称。
    var shortTitle: String { self == .pension ? "养老金" : "公积金" }
    func base(_ record: ContributionStage) -> Int64? { self == .pension ? record.pensionBaseCents : record.housingBaseCents }
    func rate(_ record: ContributionStage) -> Int64? { self == .pension ? record.pensionBasisPoints : record.housingBasisPoints }
    func hasValues(_ record: ContributionStage) -> Bool { base(record) != nil || rate(record) != nil }
}

struct ContributionEstimate {
    /// 金额，单位为分。
    let amountCents: Int64
    /// 纳入统计的月份数量。
    let coveredMonths: Int
}

enum ContributionEstimateRules {
    static func calculate(_ records: [ContributionStage], for job: Employment, kind: ContributionKind, through date: Date) -> ContributionEstimate? {
        guard let jobStart = job.start else { return nil }
        let calendar = ProfileRules.calendar
        let first = CareerRules.monthStart(jobStart)
        let last = CareerRules.monthStart(min(job.end ?? date, date))
        guard first <= last else { return nil }
        let stages = CareerRules.contributions(records, for: job, kind: kind)
        var month = first
        var amount: Int64 = 0
        var covered = 0
        while month <= last {
            if let stage = stages.first(where: { $0.effectiveMonth <= month }),
               let monthly = ProfileRules.monthlyContribution(salaryCents: kind.base(stage), rateBasisPoints: kind.rate(stage)) {
                let (total, totalOverflow) = amount.addingReportingOverflow(monthly)
                guard !totalOverflow else { return nil }
                amount = total
                covered += 1
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { return nil }
            month = next
        }
        return covered == 0 ? nil : ContributionEstimate(amountCents: amount, coveredMonths: covered)
    }
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
        /// 天数。
        let days: Int
        /// 缺少法定节假日资料的年份集合。
        let missingHolidayYears: Bool
        /// 平均每日工资，单位为分。
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
