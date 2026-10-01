import SwiftUI
import SwiftData

enum WealthDestination: Hashable {
    case debtExample
    case stocks
    case holding(String)
}

@Observable final class AppNavigation {
    var selectedTab: AppTab = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--analysis") { return .analysis }
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
