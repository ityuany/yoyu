import SwiftUI
import SwiftData

@main struct yoyuApp: App {
    private let storage = AppStorageController()

    var body: some Scene {
        WindowGroup {
            if let container = storage.container {
                ContentView()
                    .modelContainer(container)
                    .environment(storage.sync)
                    .environment(\.locale, Locale(identifier: "zh_CN"))
            } else {
                ContentUnavailableView("无法打开本机数据", systemImage: "externaldrive.badge.exclamationmark", description: Text(storage.errorMessage ?? "请重新启动应用后重试。"))
            }
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--profile") { return .profile }
        #endif
        return .today
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    if tab == .profile {
                        ProfileView()
                    } else {
                        Color.clear
                    }
                }
            }
        }
    }
}

private enum AppTab: CaseIterable, Identifiable {
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
