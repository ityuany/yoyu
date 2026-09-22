import Foundation
import Observation

/// Session-only derived results. User plans remain in SwiftData + CloudKit.
@MainActor final class RunwayCache {
    private var entries: [String: RunwayResult] = [:]
    private var order: [String] = []
    func result(for key: String) -> RunwayResult? { entries[key] }
    func store(_ result: RunwayResult, for key: String) {
        entries[key] = result
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > 3 { entries.removeValue(forKey: order.removeFirst()) }
    }
}
