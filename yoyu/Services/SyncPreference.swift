import Foundation
import Observation

/// Device-only settings, deliberately excluded from CloudKit business data.
@Observable
final class SyncPreference {
    private let defaults: UserDefaults
    private(set) var enabled: Bool
    private(set) var approvedAccount: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.object(forKey: "cloudSync.enabled") as? Bool ?? true
        approvedAccount = defaults.string(forKey: "cloudSync.approvedAccount")
    }

    func setEnabled(_ value: Bool) {
        defaults.set(value, forKey: "cloudSync.enabled")
        enabled = value
    }

    func approve(account: String) {
        defaults.set(account, forKey: "cloudSync.approvedAccount")
        approvedAccount = account
    }
}
