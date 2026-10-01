import SwiftData

/// 应用持久化模型的统一入口，集中展示业务实体和明细实体。
/// 值类型草稿与计算结果不在此注册。
enum AppModelSchema {
    /// 使用同一本地数据库及 CloudKit 私有数据库的完整模型结构。
    static var schema: Schema {
        Schema([
            // 个人资料与日期调整。
            UserProfile.self,
            WorkdayOverride.self,
            // 任职、薪资、奖金与缴纳记录。
            Employment.self,
            SalaryStage.self,
            BonusPayment.self,
            ContributionStage.self,
            // 缴纳上下限及内置资料导入状态。
            SocialInsuranceLimit.self,
            SocialInsuranceLimitSeedState.self,
            HousingFundLimit.self,
            HousingFundLimitSeedState.self,
            // 持仓 → 授予批次 → 归属分期；持仓 → 处置记录。
            StockHolding.self,
            EquityGrantRecord.self,
            EquityInstallmentRecord.self,
            EquityDisposalRecord.self,
            // 负债账户 → 房贷组成、信用卡分期。
            LiabilityAccount.self,
            MortgagePartRecord.self,
            CardInstallmentRecord.self,
            // 预计支出与预测配置。
            RecurringExpense.self,
            RunwaySettings.self,
        ])
    }
}
