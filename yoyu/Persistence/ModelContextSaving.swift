import Foundation
import SwiftData

extension ModelContext {
    /// Saves pending changes, rolling back on failure.
    /// - Returns: `nil` on success, otherwise a message to show the user.
    func saveOrRollback() -> String? {
        do {
            try save()
            return nil
        } catch {
            rollback()
            return error.localizedDescription
        }
    }
}
