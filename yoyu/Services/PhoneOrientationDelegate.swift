import UIKit

/// iPhone screens remain portrait; the full-screen chart rotates its own content.
@MainActor
final class PhoneOrientationDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        window?.traitCollection.userInterfaceIdiom == .phone ? .portrait : .all
    }
}
