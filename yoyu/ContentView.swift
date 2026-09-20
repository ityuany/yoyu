import SwiftUI
import SwiftData

@main struct yoyuApp: App {
    @UIApplicationDelegateAdaptor(PhoneOrientationDelegate.self) private var orientationDelegate
    @State private var storage = AppStorageController()

    var body: some Scene {
        WindowGroup {
            if let container = storage.container {
                ContentView()
                    .modelContainer(container)
                    .environment(storage.sync)
                    .environment(\.locale, Locale(identifier: "zh_CN"))
            } else if storage.errorMessage == nil {
                VStack(spacing: 20) {
                    ProgressView("正在准备数据…")
                    Button("先使用本地数据") { storage.continueLocally() }
                }
                .task { await storage.start() }
            } else {
                ContentUnavailableView("无法打开本机数据", systemImage: "externaldrive.badge.exclamationmark", description: Text(storage.errorMessage ?? "请重新启动应用后重试。"))
            }
        }
    }
}

@Observable final class CareerClock {
    var now = Date()
}

enum WealthDestination: Hashable {
    case debtExample
    case stocks
    case holding(String)
}

@Observable final class AppNavigation {
    var selectedTab: AppTab = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--wealth") { return .wealth }
        if ProcessInfo.processInfo.arguments.contains("--profile") { return .profile }
        #endif
        return .today
    }()
    var wealthPath: NavigationPath = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--debt-example") { return NavigationPath([WealthDestination.debtExample]) }
        #endif
        return NavigationPath()
    }()

    func openStocks(holdingID: String? = nil) {
        var path = NavigationPath()
        path.append(WealthDestination.stocks)
        if let holdingID { path.append(WealthDestination.holding(holdingID)) }
        wealthPath = path
        selectedTab = .wealth
    }
}

struct ContentView: View {
    @State private var careerClock = CareerClock()
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigation = AppNavigation()

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    Group {
                        if tab == .today {
                            TodayView()
                        } else if tab == .wealth {
                            WealthView()
                        } else if tab == .profile {
                            ProfileView()
                        } else {
                            NavigationStack {
                                DashboardStyle.background
                                    .ignoresSafeArea()
                                    .dashboardTabRoot(title: tab.title)
                            }
                        }
                    }
                    .tint(DashboardStyle.accent)
                }
            }
        }
        .tint(DashboardStyle.tabSelection)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .environment(careerClock)
        .environment(navigation)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { careerClock.now = Date() }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            // 页面保持打开或从后台恢复时，也刷新按生效日期读取的当前待遇。
            while !Task.isCancelled {
                careerClock.now = Date()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }
}

enum AppTab: CaseIterable, Identifiable {
    case today
    case wealth
    case forecast
    case profile

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "今日"
        case .wealth: "财富"
        case .forecast: "预测"
        case .profile: "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .wealth: "wallet.bifold"
        case .forecast: "chart.line.uptrend.xyaxis"
        case .profile: "person.crop.circle"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, WorkdayOverride.self], inMemory: true)
        .environment(SyncMonitor())
}
