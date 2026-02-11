import SwiftUI
import UIKit
import KotoKit

@main
struct KotoiOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        KotoAppScene().body
    }
}

private final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UIApplication.shared.applicationIconBadgeNumber = 0
        return true
    }
}
