import SwiftUI
import SwiftData

/// 资料详情随查询结果更新；编辑仍使用独立草稿，取消不会改变详情。
struct ProfileDetailView: View {
    let section: ProfileSection
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query private var stocks: [StockHolding]
    @Environment(AppNavigation.self) private var navigation
    @Environment(CareerClock.self) private var clock
    @State private var isEditing = false

    private var profile: UserProfile? {
        profiles.max { $0.updatedAt(for: section) < $1.updatedAt(for: section) }
    }

    private var title: String { section == .employment ? "薪资待遇" : section.rawValue }

    var body: some View {
        List {
            switch section {
            case .basic: basicDetails
            case .employment: CareerView(destination: .salary)
            case .work: CareerView(destination: .work)
            case .wealth: wealthDetails
            }
        }.neutralPageBackground()
        .navigationTitle(title)
        #if os(iOS)
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("编辑") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            ProfileEditor(section: section, profile: profile)
        }
    }

    private var birthDate: String {
        guard let year = profile?.birthYear, let month = profile?.birthMonth else { return "待填写" }
        return "\(year) 年 \(month) 月"
    }

    private var gender: String {
        guard let value = profile?.gender, !value.isEmpty else { return "待填写" }
        return value
    }

    private var basicDetails: some View {
        Group {
            Section {
                LabeledContent("出生年月", value: birthDate)
                LabeledContent("性别", value: gender)
                LabeledContent("法定退休年月", value: profile?.retirement ?? "待完善")
            } header: { Text("个人信息") } footer: {
                Text("按中国大陆普通职工渐进式延迟退休规则计算，不含特殊工种等提前退休情形。")
            }
            CurrentEmploymentSection()
        }
    }

    private var wealthDetails: some View {
        Group {
            Section {
                Text(ProfileRules.money(StockRules.wealth(stocks, profile: profile, on: clock.now)))
                    .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    .minimumScaleFactor(0.65)
                    .padding(.vertical, 8)
            } header: { Text("当前财富合计") } footer: {
                Text("总额汇总现金、已归属股票与理财；未归属部分不计入。外币股票按手动汇率折算人民币。")
            }
            Section("现金") {
                LabeledContent("当前金额", value: ProfileRules.money(profile?.cashCents))
            }
            Section("股票") {
                LabeledContent("已归属价值", value: ProfileRules.money(StockRules.portfolio(stocks, profile: profile, on: clock.now)))
                LabeledContent("未归属价值", value: ProfileRules.money(StockRules.portfolio(stocks, profile: profile, on: clock.now, unvested: true)))
                Button("前往财富管理股票") { navigation.openStocks() }
            }
            Section("理财") {
                LabeledContent("当前估算金额", value: ProfileRules.money(profile?.investmentValue(on: clock.now)))
                LabeledContent("初始本金", value: ProfileRules.money(profile?.investmentCents))
                LabeledContent("登记日期", value: profile?.investmentRegistrationDate.map { CareerRules.dateLabel($0) } ?? "待补登记日期")
                LabeledContent("年化收益率", value: profile?.investmentAnnualReturnBasisPoints.map {
                    "\(ProfileRules.input($0))%"
                } ?? "待填写")
            }
        }
    }
}
