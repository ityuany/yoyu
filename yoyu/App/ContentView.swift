import SwiftUI
import SwiftData

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
                        } else if tab == .forecast {
                            RunwayView()
                        } else {
                            ProfileView()
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

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, WorkdayOverride.self], inMemory: true)
        .environment(SyncMonitor())
}
