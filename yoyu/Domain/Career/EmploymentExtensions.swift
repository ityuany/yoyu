import Foundation

extension Employment {
    /// 用于界面展示的名称。
    var displayName: String { name.isEmpty ? "企业名称待完善" : name }

    /// 是否为当前任职。
    var isCurrent: Bool { isCurrent(on: Date()) }

    func isCurrent(on date: Date) -> Bool { (start ?? .distantPast) <= date && end == nil }
}
