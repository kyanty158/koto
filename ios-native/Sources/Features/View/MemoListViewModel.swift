import Foundation
import CoreData

@available(iOS 15.0, macOS 12.0, *)
@MainActor
final public class MemoListViewModel: NSObject, ObservableObject {
    @Published var upcoming: [MemoModel] = []
    @Published var history: [MemoModel] = []
    @Published var searchTerm: String = "" {
        didSet {
            Task { await reload() }
        }
    }
    @Published var selectionMode: Bool = false
    @Published var selectedIDs: Set<Int64> = []

    private let repository: MemoRepository
    private let subscriptionManager: SubscriptionManager
    private var controller: NSFetchedResultsController<MemoEntity>?

    init(repository: MemoRepository, subscriptionManager: SubscriptionManager) {
        self.repository = repository
        self.subscriptionManager = subscriptionManager
        super.init()
        Task { await reload() }
    }

    func reload() async {
        controller?.delegate = nil
        let limit = subscriptionManager.maxVisibleMemos
        let newController = repository.fetchedResultsController(searchTerm: subscriptionManager.canSearch ? searchTerm.trimmed : nil,
                                                                limit: limit)
        controller = newController
        controller?.delegate = self
        applySnapshot()
    }

    func toggleSelection(for memo: MemoModel) {
        if selectedIDs.contains(memo.id) {
            selectedIDs.remove(memo.id)
        } else {
            selectedIDs.insert(memo.id)
        }
    }

    func deleteSelected() throws {
        try repository.delete(ids: Array(selectedIDs))
        selectedIDs.removeAll()
    }

    func markDone(_ memo: MemoModel, done: Bool) {
        try? repository.markDone(id: memo.id, done: done)
    }

    func memo(for id: Int64) -> MemoModel? {
        try? repository.memo(for: id)
    }

    private func applySnapshot() {
        upcoming = (try? repository.upcomingReminders(limit: 6)) ?? []
        let entities = controller?.fetchedObjects ?? []
        let upcomingIDs = Set(upcoming.map(\.id))
        history = entities
            .map(MemoModel.init(entity:))
            .filter { !upcomingIDs.contains($0.id) }
    }
}

@available(iOS 15.0, macOS 12.0, *)
extension MemoListViewModel: NSFetchedResultsControllerDelegate {
    nonisolated public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        Task { @MainActor [weak self] in
            self?.applySnapshot()
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
