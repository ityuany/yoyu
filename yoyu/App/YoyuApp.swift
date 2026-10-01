import SwiftUI
import SwiftData

@main struct yoyuApp: App {
    @UIApplicationDelegateAdaptor(PhoneOrientationDelegate.self) private var orientationDelegate
    @State private var storage = AppStorageController()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let scenario = AppTestScenario.current {
                scenario.content.appTheme()
            } else {
                appContent.appTheme()
            }
            #else
            appContent.appTheme()
            #endif
        }
    }

    private var appContent: some View {
        Group {
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
