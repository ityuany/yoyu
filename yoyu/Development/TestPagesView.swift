#if DEBUG
import SwiftUI

/// 开发用页面目录。沿用现有场景的独立数据容器，不向真实账本写入示例数据。
struct TestPagesView: View {
    @State private var selected: TestPage?

    var body: some View {
        List {
            Section("概览与配色") {
                ForEach(TestPage.themePages) { page in entry(page) }
            }
            Section("业务场景") {
                ForEach(AppTestScenario.allCases.filter { $0 != .theme }) { scenario in
                    entry(TestPage(scenario: scenario))
                }
            }
        }
        .listStyle(.insetGrouped)
        .neutralPageBackground()
        .navigationTitle("测试页面")
        .navigationBarTitleDisplayMode(.inline)
        // 场景自带导航栈，有的还包含完整标签栏。独立展示，避免嵌套导航或双层标签栏。
        .fullScreenCover(item: $selected) { page in
            page.content
                .appTheme()
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack {
                        Text(page.title).font(.headline)
                        Spacer()
                        Button("关闭") { selected = nil }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("testPages.close")
                    }
                    .padding(.horizontal)
                    .background(.regularMaterial)
                }
        }
    }

    private func entry(_ page: TestPage) -> some View {
        Button { selected = page } label: {
            HStack {
                Text(page.title).foregroundStyle(.primary)
                Spacer()
                OverviewCardDisclosure(isVisible: true)
            }
        }
        .accessibilityIdentifier("testPages.\(page.id)")
        .listRowBackground(AppTheme.cardBackground)
    }
}

/// 配色和大额数据作为同一场景的参数，避免复制测试页面实现。
private struct TestPage: Identifiable {
    let scenario: AppTestScenario
    var dark = false
    var largeValues = false

    var id: String {
        scenario == .theme ? "theme-\(dark ? "dark" : "light")-\(largeValues ? "large" : "regular")" : scenario.id
    }

    var title: String {
        scenario == .theme ? "\(largeValues ? "大额数据" : "整体概览") · \(dark ? "深色" : "浅色")" : scenario.title
    }

    static let themePages = [
        TestPage(scenario: .theme),
        TestPage(scenario: .theme, dark: true),
        TestPage(scenario: .theme, largeValues: true),
        TestPage(scenario: .theme, dark: true, largeValues: true)
    ]

    @ViewBuilder var content: some View {
        if scenario == .theme {
            ThemeTestHost(appearance: dark ? .dark : .light, largeValues: largeValues)
        } else {
            scenario.content
        }
    }
}
#endif
