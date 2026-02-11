import Foundation

@MainActor
final class MemoUndoManager: ObservableObject {
    private let repository: MemoRepository
    private var lastSaved: MemoModel?
    private var lastDiscardedText: String?
    private var lastDiscardedReminder: Date?

    init(repository: MemoRepository) {
        self.repository = repository
    }

    func cacheLastSaved(_ memo: MemoModel) {
        lastSaved = memo
    }

    func cacheDiscard(text: String, reminder: Date?) {
        lastDiscardedText = text
        lastDiscardedReminder = reminder
    }

    var lastSavedMemo: MemoModel? {
        lastSaved
    }

    var hasDiscard: Bool {
        lastDiscardedText != nil
    }

    var lastDiscardText: String? { lastDiscardedText }
    var lastDiscardReminder: Date? { lastDiscardedReminder }

    func undoLastSave() throws {
        guard let saved = lastSaved else { return }
        try repository.delete(ids: [saved.id])
        lastSaved = nil
    }

    func restoreDiscard(repository: MemoRepository, inlineTags: [String]) throws -> MemoModel? {
        guard let text = lastDiscardedText else { return nil }
        let memo = try repository.createMemo(text: text, reminderAt: lastDiscardedReminder, inlineTags: inlineTags)
        lastDiscardedText = nil
        lastDiscardedReminder = nil
        return memo
    }
}
