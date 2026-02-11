import Foundation

@available(iOS 15.0, macOS 12.0, *)
@MainActor
final class AppEnvironment: ObservableObject {
    let persistence: PersistenceController
    let memoRepository: MemoRepository
    let subscriptionManager: SubscriptionManager
    let notificationService: NotificationService
    let undoManager: MemoUndoManager
    var presetStore: CustomReminderPresetStore
    @Published var pendingEditMemo: MemoModel?

    init(persistence: PersistenceController = .shared,
         subscriptionManager: SubscriptionManager? = nil) {
        self.persistence = persistence
        self.memoRepository = MemoRepository(container: persistence.container)
        let resolvedSubscription = subscriptionManager ?? SubscriptionManager()
        self.subscriptionManager = resolvedSubscription
        self.undoManager = MemoUndoManager(repository: memoRepository)
        self.notificationService = NotificationService(repository: memoRepository)
        self.presetStore = CustomReminderPresetStore()
    }

    func routeToEditMemo(id: Int64) {
        pendingEditMemo = (try? memoRepository.memo(for: id)) ?? nil
    }
}
