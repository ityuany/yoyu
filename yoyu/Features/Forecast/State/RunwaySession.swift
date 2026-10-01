import Foundation
import Observation

/// The model-backed inputs are read on the main actor. RunwayEngine builds value
/// snapshots before its daily simulation leaves that actor.
@MainActor struct RunwayInput {
    /// 方案或配置。
    let plan: RunwayPlan
    /// 个人资料。
    let profile: UserProfile?
    /// 股票持仓集合。
    let stocks: [StockHolding]
    /// 任职记录集合。
    let jobs: [Employment]
    /// 薪资阶段集合。
    let stages: [SalaryStage]
    /// 年终奖记录集合。
    let bonuses: [BonusPayment]
    /// 预计支出记录。
    let expenses: [RecurringExpense]
    /// 负债记录集合。
    let liabilities: [LiabilityAccount]
    /// 本次计算采用的当前日期。
    let today: Date
    /// 输入数据版本，用于识别计算缓存。
    let revision: String

    init(plan: RunwayPlan, profile: UserProfile?, stocks: [StockHolding], jobs: [Employment],
         stages: [SalaryStage], bonuses: [BonusPayment], expenses: [RecurringExpense],
         liabilities: [LiabilityAccount], today: Date) {
        self.plan = plan
        self.profile = profile
        self.stocks = stocks
        self.jobs = jobs
        self.stages = stages
        self.bonuses = bonuses
        self.expenses = expenses
        self.liabilities = liabilities
        self.today = today

        let wealthValues: [String?] = profile.map { p in
            [p.wealthUpdatedAt?.timeIntervalSinceReferenceDate.description,
             p.cashCents?.description, p.stockCents?.description,
             p.stockSharesHundredths?.description, p.stockPriceCents?.description,
             p.investmentCents?.description, p.investmentAnnualReturnBasisPoints?.description,
             p.investmentInterestMode,
             p.investmentRegistrationDate?.timeIntervalSinceReferenceDate.description]
        } ?? []
        let wealthRevision = profile == nil ? "no-profile" : wealthValues.map { $0 ?? "nil" }.joined(separator: "/")
        func revisions<T>(_ values: [T], id: (T) -> String, modifiedAt: (T) -> Date) -> String {
            values.map { "\(id($0))\(modifiedAt($0).timeIntervalSinceReferenceDate)" }.sorted().joined()
        }
        // 关联明细可能晚于父记录到达；内容也参与版本，避免沿用未到齐时的缓存。
        // 此处 JSON 仅生成内存缓存标识，不写入持久化字段。
        func content<T: Encodable>(_ value: T?) -> String {
            guard let value else { return "unavailable" }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return (try? encoder.encode(value).base64EncodedString()) ?? "invalid"
        }
        let detailsRevision = [
            stocks.map { "\($0.id):\(content($0.grants)):\(content($0.disposals))" }.sorted().joined(separator: ";"),
            liabilities.map { "\($0.id):\(content($0.snapshot))" }.sorted().joined(separator: ";"),
            expenses.map { "\($0.id):\(content($0.plan))" }.sorted().joined(separator: ";"),
            jobs.map { "\($0.id):\(content(SeveranceRules.settings(for: $0)))" }.sorted().joined(separator: ";")
        ].joined(separator: "|")
        revision = [detailsRevision, ProfileRules.dateKey(today), plan.mode.rawValue, plan.cacheKey,
                    wealthRevision,
                    profile?.birthYear.map(String.init) ?? "nil",
                    profile?.birthMonth.map(String.init) ?? "nil",
                    profile?.gender ?? "nil",
                    profile?.femaleRetirementAge.map(String.init) ?? "nil",
                    revisions(jobs, id: { $0.id }, modifiedAt: { $0.modifiedAt }),
                    revisions(stages, id: { $0.id }, modifiedAt: { $0.modifiedAt }),
                    revisions(stocks, id: { $0.id }, modifiedAt: { $0.modifiedAt }),
                    revisions(bonuses, id: { $0.id }, modifiedAt: { $0.modifiedAt }),
                    revisions(expenses, id: { $0.id }, modifiedAt: { $0.modifiedAt }),
                    revisions(liabilities, id: { $0.id }, modifiedAt: { $0.modifiedAt })]
            .joined(separator: "|")
    }
}

/// Owns the whole calculation session: input identity, in-flight work and a
/// three-result memory cache. Plans and records remain in SwiftData + CloudKit.
@MainActor @Observable final class RunwaySession {
    typealias Calculation = @MainActor (RunwayInput) async -> RunwayResult

    /// 计算结果。
    private(set) var result: RunwayResult?
    /// 生成当前结果时使用的方案。
    private(set) var resultPlan: RunwayPlan?
    /// 是否正在计算。
    private(set) var isCalculating = false
    /// 当前正在计算的输入版本。
    private(set) var activeRevision: String?
    /// 当前计算请求标识，用于丢弃过期计算结果。
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var entries: [String: RunwayResult] = [:]
    @ObservationIgnored private var order: [String] = []
    @ObservationIgnored private let calculate: Calculation

    init(calculate: @escaping Calculation = { input in
        await RunwayEngine.calculate(plan: input.plan, profile: input.profile,
            stocks: input.stocks, jobs: input.jobs, stages: input.stages,
            bonuses: input.bonuses, expenses: input.expenses,
            liabilities: input.liabilities, today: input.today)
    }) {
        self.calculate = calculate
    }

    func result(for revision: String) -> RunwayResult? {
        activeRevision == revision ? result : nil
    }

    func plan(for revision: String) -> RunwayPlan? {
        activeRevision == revision ? resultPlan : nil
    }

    func calculating(for revision: String) -> Bool {
        activeRevision == revision && isCalculating
    }

    func run(_ input: RunwayInput) async {
        let request = UUID()
        requestID = request
        activeRevision = input.revision
        result = nil
        resultPlan = nil
        if let cached = entries[input.revision] {
            result = cached
            resultPlan = input.plan
            isCalculating = false
            return
        }

        isCalculating = true
        defer { if requestID == request { isCalculating = false } }
        let next = await calculate(input)
        guard !Task.isCancelled, requestID == request, activeRevision == input.revision else { return }
        entries[input.revision] = next
        order.removeAll { $0 == input.revision }
        order.append(input.revision)
        while order.count > 3 { entries.removeValue(forKey: order.removeFirst()) }
        result = next
        resultPlan = input.plan
    }
}
