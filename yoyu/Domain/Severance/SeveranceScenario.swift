import Foundation

struct SeveranceScenario {
    /// 本次估算对应的任职记录。
    let job: Employment?
    /// 本次估算采用的补偿配置。
    let settings: SeveranceSettings?
    /// 补偿月工资基数，单位为分。
    let salaryCents: Int64?
    /// 代通知金工资基数，单位为分。
    let noticeSalaryCents: Int64?
    /// 按任职及薪资资料计算的税前补偿结果。
    let estimate: SeveranceRules.Estimate?

    init(jobs: [Employment], stages: [SalaryStage], bonuses: [BonusPayment] = [], now: Date, employmentDate: Date? = nil) {
        let current = CareerRules.current(jobs, on: employmentDate ?? now)
        job = current
        settings = current.flatMap { SeveranceRules.settings(for: $0)?.automatic }
        salaryCents = current.flatMap { SeveranceRules.averageSalary(stages: stages, bonuses: bonuses, job: $0, on: now) }
        noticeSalaryCents = current.flatMap { SeveranceRules.previousMonthSalary(stages: stages, job: $0, on: now) }
        if let current, let settings {
            estimate = SeveranceRules.estimate(settings: settings, job: current, salaryCents: salaryCents, noticeSalaryCents: noticeSalaryCents, on: now)
        } else {
            estimate = nil
        }
    }

    func estimate(for plan: SeverancePlan, on date: Date) -> SeveranceRules.Estimate? {
        guard let job, var settings else { return nil }
        settings.plan = plan
        return SeveranceRules.estimate(settings: settings, job: job, salaryCents: salaryCents,
                                      noticeSalaryCents: noticeSalaryCents, on: date)
    }

}
