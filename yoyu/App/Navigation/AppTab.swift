import SwiftUI
import SwiftData

enum AppTab: CaseIterable, Identifiable {
    case today
    case wealth
    case analysis
    case profile

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "今日"
        case .wealth: "财富"
        case .analysis: "分析"
        case .profile: "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .wealth: "wallet.bifold"
        case .analysis: "chart.bar.xaxis"
        case .profile: "person.crop.circle"
        }
    }
}
