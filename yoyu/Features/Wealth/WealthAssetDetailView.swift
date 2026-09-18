import SwiftUI
import SwiftData

/// Read-only detail backed by a live query; editing uses the existing scoped draft form.
struct WealthAssetDetailView: View {
    let asset: WealthEditScope
    @Query private var profiles: [UserProfile]
    @State private var isEditing = false

    private var profile: UserProfile? {
        profiles.max { $0.updatedAt(for: .wealth) < $1.updatedAt(for: .wealth) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardStyle.sectionSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(asset == .cash ? "当前余额" : "当前金额")
                        .font(.subheadline).foregroundStyle(.secondary)
                    DashboardAmount(value: ProfileRules.money(asset == .cash ? profile?.cashCents : profile?.investmentCents))
                    Text("人民币").font(.caption).foregroundStyle(.secondary)
                }
                .dashboardCard(highlighted: true)
                .accessibilityElement(children: .combine)

                if asset == .investment {
                    LabeledContent("年化收益率", value: profile?.investmentAnnualReturnBasisPoints.map {
                        "\(ProfileRules.input($0))%"
                    } ?? "待填写")
                    .font(.body)
                    .dashboardCard()

                    NavigationLink {
                        InvestmentProjectionView(principal: profile?.investmentCents,
                                                 annualRate: profile?.investmentAnnualReturnBasisPoints)
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
                                months: 12, mode: .simple) {
                                Text(ProfileRules.money(estimate.earningsCents))
                                    .font(.title2.weight(.semibold)).monospacedDigit()
                                Text("未来 1 年预计收益 · 单利")
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
}
