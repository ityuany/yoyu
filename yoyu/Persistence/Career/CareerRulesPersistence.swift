import Foundation
import SwiftData

/// 数据库操作保留原调用入口，集中由持久化层负责。
extension CareerRules {
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
