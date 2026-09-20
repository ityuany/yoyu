import SwiftUI
import SwiftData

/// Read-only detail backed by a live query; editing uses the existing scoped draft form.
struct WealthAssetDetailView: View {
    let asset: WealthEditScope
    @Query private var profiles: [UserProfile]
    @State private var isEditing = false
    @Environment(CareerClock.self) private var clock

    private var profile: UserProfile? {
        profiles.max { $0.updatedAt(for: .wealth) < $1.updatedAt(for: .wealth) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardStyle.sectionSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(asset == .cash ? "当前余额" : "当前估算金额")
                        .font(.subheadline).foregroundStyle(.secondary)
                    DashboardAmount(value: ProfileRules.money(asset == .cash ? profile?.cashCents : profile?.investmentValue(on: clock.now)))
                    Text("人民币").font(.caption).foregroundStyle(.secondary)
                }
                .dashboardCard(highlighted: true)
                .accessibilityElement(children: .combine)

                if asset == .investment {
                    VStack(spacing: 16) {
                        LabeledContent("初始本金", value: ProfileRules.money(profile?.investmentCents))
                        LabeledContent("登记日期", value: profile?.investmentRegistrationDate.map { CareerRules.dateLabel($0) } ?? "待补登记日期")
                        LabeledContent("年化收益率", value: profile?.investmentAnnualReturnBasisPoints.map {
                            "\(ProfileRules.input($0))%"
                        } ?? "待填写")
                        LabeledContent("计息方式", value: profile?.investmentInterestMode ?? "单利")
                        LabeledContent("累计估算收益", value: ProfileRules.money(accruedEarnings))
                    }
                    .font(.body)
                    .monospacedDigit()
                    .dashboardCard()

                    Text("从登记日零点起算，一年按 365 天。单利按初始本金计息；复利每年复投，未满一年按时间比例折算。金额随时间更新，为估算值。")
                        .font(.caption).foregroundStyle(.secondary)
                    if profile?.investmentRegistrationDate == nil || profile?.investmentAnnualReturnBasisPoints == nil {
                        Text("补齐登记日期与年化收益率后开始估算，当前暂按本金显示。")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        InvestmentProjectionView(principal: profile?.investmentCents,
                                                 annualRate: profile?.investmentAnnualReturnBasisPoints,
                                                 mode: investmentMode)
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("收益测算", systemImage: "chart.line.uptrend.xyaxis")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            }
                            if let estimate = InvestmentProjection.calculate(
                                principal: profile?.investmentCents,
                                rate: profile?.investmentAnnualReturnBasisPoints,
                                months: 12, mode: investmentMode) {
                                Text(ProfileRules.money(estimate.earningsCents))
                                    .font(.title2.weight(.semibold)).monospacedDigit()
                                Text("初始本金的年度收益参考 · \(investmentMode.rawValue)")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("填写本金和年化收益率，预览未来收益。")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(DashboardStyle.investment)
                        .dashboardCard()
                    }
                    .buttonStyle(.plain)
                }

                Text("未填写表示未知，0 表示没有。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, DashboardStyle.pageInset)
            .padding(.top, 8)
            .padding(.bottom, DashboardStyle.sectionSpacing)
        }
        .background(DashboardStyle.background)
        .navigationTitle(asset == .cash ? "现金" : "理财")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("编辑") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            ProfileEditor(section: .wealth, profile: profile, wealthScope: asset)
        }
    }

    private var investmentMode: InvestmentInterestMode {
        InvestmentInterestMode(rawValue: profile?.investmentInterestMode ?? "") ?? .simple
    }

    private var accruedEarnings: Int64? {
        guard let profile, profile.investmentRegistrationDate != nil,
              profile.investmentAnnualReturnBasisPoints != nil,
              let principal = profile.investmentCents,
              let current = profile.investmentValue(on: clock.now) else { return nil }
        return current - principal
    }
}
