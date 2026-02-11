import SwiftUI

// 起動時刻計測（できるだけ早く確定）
enum LaunchTimer {
    static let launchTime = CFAbsoluteTimeGetCurrent()
    
    static func elapsed() -> Double {
        CFAbsoluteTimeGetCurrent() - launchTime
    }
    
    static func logKeyboardReady() {
        #if DEBUG
        print("🚀 Launch → Keyboard: \(String(format: "%.3f", elapsed()))s")
        #endif
    }
}

@available(iOS 15.0, macOS 12.0, *)
public struct KotoAppScene: App {
    @StateObject private var environment: AppEnvironment
    @StateObject private var writeViewModel: WriteViewModel
    @StateObject private var listViewModel: MemoListViewModel

    public init() {
        let env = AppEnvironment()
        _environment = StateObject(wrappedValue: env)
        _writeViewModel = StateObject(wrappedValue: WriteViewModel(repository: env.memoRepository,
                                                                   subscriptionManager: env.subscriptionManager,
                                                                   notificationService: env.notificationService,
                                                                   undoManager: env.undoManager))
        _listViewModel = StateObject(wrappedValue: MemoListViewModel(repository: env.memoRepository,
                                                                     subscriptionManager: env.subscriptionManager))
        env.notificationService.onEditRequested = { [weak appEnvironment = env] memoId in
            Task { @MainActor in
                guard let appEnvironment else { return }
                appEnvironment.routeToEditMemo(id: memoId)
            }
        }
    }

    public var body: some Scene {
        WindowGroup {
            ContentView(writeViewModel: writeViewModel,
                        listViewModel: listViewModel)
                .environmentObject(environment)
        }
    }
}
public enum AppTab: String, Hashable {
    case write
    case list
    case settings
}
