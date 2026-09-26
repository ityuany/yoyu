import SwiftUI
import SwiftData

#if DEBUG
struct SocialInsuranceLimitsTestHost: View {
    private let container: ModelContainer? = {
        do {
            let schema = Schema([SocialInsuranceLimit.self, SocialInsuranceLimitSeedState.self, HousingFundLimit.self, HousingFundLimitSeedState.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            try SocialInsuranceLimitDefaults.importIfNeeded(context: ModelContext(container))
            try HousingFundLimitDefaults.importIfNeeded(context: ModelContext(container))
            return container
        } catch {
            return nil
        }
    }()

    var body: some View {
        Group {
            if let container {
                NavigationStack {
                    List {
                        NavigationLink("养老保险", value: ProfileRoute.detail(.basic))
                            .accessibilityIdentifier("profile.pension")
                        NavigationLink("住房公积金", value: ProfileRoute.housingFundLimits)
                            .accessibilityIdentifier("profile.housing")
                    }
                        .navigationDestination(for: ProfileRoute.self) { route in
                            switch route {
                            case .detail(.basic):
                                List {
                                    NavigationLink("基数范围", value: ProfileRoute.socialInsuranceLimits)
                                        .accessibilityIdentifier("pension.baseRange")
                                }
                                .navigationTitle("养老保险")
                            case .socialInsuranceLimits:
                                SocialInsuranceLimitsView()
                            case .housingFundLimits:
                                HousingFundLimitsView()
                            default:
                                EmptyView()
                            }
                        }
                }
                .modelContainer(container)
                .environment(\.locale, Locale(identifier: "zh_CN"))
            } else {
                ContentUnavailableView("测试资料不可用", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
#endif
