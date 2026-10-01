import Foundation
import Observation
import SwiftData
import CloudKit
import CoreData

struct SyncIssue {
    let phase: String
    let date: Date
    let details: String

    init(error: Error?, phase: String, date: Date) {
        self.phase = phase
        self.date = date
        if let error {
            var visited = Set<ObjectIdentifier>()
            self.details = Self.describe(error as NSError, depth: 0, visited: &visited)
        } else {
            self.details = "系统报告同步未完成，但没有提供具体错误。请等待后续同步事件。"
        }
    }

    var report: String {
        "失败环节：\(phase)\n时间：\(date.formatted(date: .numeric, time: .standard))\n\(details)"
    }

    private static func describe(_ error: NSError, depth: Int, visited: inout Set<ObjectIdentifier>) -> String {
        guard depth < 8, visited.insert(ObjectIdentifier(error)).inserted else { return "（重复或过深的错误信息已省略）" }
        var lines = ["\(error.domain) · 错误码 \(error.code)", error.localizedDescription]
        if let reason = error.localizedFailureReason { lines.append("原因：" + reason) }
        if let suggestion = error.localizedRecoverySuggestion { lines.append("建议：" + suggestion) }
        if let retry = error.userInfo[CKErrorRetryAfterKey] as? NSNumber {
            lines.append("系统建议 \(retry) 秒后重试；实际传输由系统调度。")
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            lines.append("底层错误：\n" + describe(underlying, depth: depth + 1, visited: &visited))
        }
        if let detailed = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
            for item in detailed.prefix(10) {
                lines.append("详细错误：\n" + describe(item, depth: depth + 1, visited: &visited))
            }
            if detailed.count > 10 { lines.append("其余详细错误已省略。") }
        }
        // Only include errors, not record identifiers or business data from userInfo.
        if let partial = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: NSError] {
            for item in partial.values.prefix(10) {
                lines.append("部分项目错误：\n" + describe(item, depth: depth + 1, visited: &visited))
            }
            if partial.count > 10 { lines.append("其余项目错误已省略。") }
        }
        return lines.joined(separator: "\n")
    }
}
