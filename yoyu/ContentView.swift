import SwiftUI

@main struct yoyuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    Color.clear
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
}
