import Foundation

@main struct SyncPreferenceTests {
    static func main() {
        let name = "yoyu.sync.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = SyncPreference(defaults: defaults)
        precondition(settings.enabled && settings.approvedAccount == nil)
        settings.setEnabled(false)
        settings.approve(account: "account-A")
        let reopened = SyncPreference(defaults: defaults)
        precondition(!reopened.enabled && reopened.approvedAccount == "account-A")
        reopened.setEnabled(true)
        precondition(reopened.approvedAccount != "account-B")
        reopened.approve(account: "account-B")
        precondition(SyncPreference(defaults: defaults).approvedAccount == "account-B")
        print("Sync preference persistence and account consent tests passed")
    }
}
