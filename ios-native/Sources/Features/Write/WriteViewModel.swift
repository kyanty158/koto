import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 15.0, macOS 12.0, *)
@MainActor
final public class WriteViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var showReminderRail: Bool = false
    @Published var highlightedPresetID: ReminderPreset.ID?
    @Published var lastSavedReminder: Date?
    @Published var showSaveAffix: Bool = false
    @Published var showRightSaveCheck: Bool = false
    @Published var rightSaveLabel: String?
    @Published var feedbackMessage: String?

    private let repository: MemoRepository
    private let subscriptionManager: SubscriptionManager
    private let notificationService: NotificationScheduling
    private let undoManager: MemoUndoManager
#if canImport(UIKit)
    private var haptic = UIImpactFeedbackGenerator(style: .medium)
#else
    private var haptic = HapticFallback()
#endif
    private var lastAction: LastAction = .none

    init(repository: MemoRepository,
         subscriptionManager: SubscriptionManager,
         notificationService: NotificationScheduling,
         undoManager: MemoUndoManager) {
        self.repository = repository
        self.subscriptionManager = subscriptionManager
        self.notificationService = notificationService
        self.undoManager = undoManager
    }

    func save(reminder: Date?, label: String?) async {
        do {
            try validateReminderQuotaIfNeeded(reminder: reminder)
            let inlineTags = InlineTagExtractor.extract(from: text)
            let memo = try repository.createMemo(text: text, reminderAt: reminder, inlineTags: inlineTags)
            undoManager.cacheLastSaved(memo)
            if let reminder {
                try await notificationService.schedule(id: memo.id,
                                                       when: reminder,
                                                       title: "すぐメモ リマインダー",
                                                       body: memo.text)
                haptic.impactOccurred()
                lastSavedReminder = reminder
                showSaveAffix = true
                showRightSaveCheck = true
                rightSaveLabel = label ?? format(reminder: reminder)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    self.showSaveAffix = false
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    self.showRightSaveCheck = false
                }
            }
            text = ""
            setFeedback(reminder != nil ? "リマインダーで保存しました" : "保存しました")
            lastAction = reminder != nil ? .savedWithReminder : .saved
        } catch WriteError.reminderQuotaReached {
            setFeedback("今月のリマインダー上限に達しました（Basic: 5件）")
        } catch {
            setFeedback("保存に失敗しました: \(error.localizedDescription)")
        }
    }

    func saveWithoutReminder() async {
        await save(reminder: nil, label: nil)
    }

    func discardCurrent(reminder: Date?) {
        guard !text.isEmpty else { return }
        undoManager.cacheDiscard(text: text, reminder: reminder)
        text = ""
        setFeedback("破棄しました")
        lastSavedReminder = nil
        lastAction = .discarded
    }

    func undoLastSave(reminderHandler: (MemoModel) async -> Void = { _ in }) async {
        switch lastAction {
        case .discarded:
            // Restore discard
            if let text = undoManager.lastDiscardText {
                let inlineTags = InlineTagExtractor.extract(from: text)
                if let restored = try? undoManager.restoreDiscard(repository: repository, inlineTags: inlineTags) {
                    await reminderHandler(restored)
                    setFeedback("破棄を元に戻しました")
                    lastAction = .restoredDiscard
                }
            }
        case .saved, .savedWithReminder:
            let lastSaved = undoManager.lastSavedMemo
            try? undoManager.undoLastSave()
            setFeedback("保存を取り消しました")
            lastAction = .undidSave
            if let lastSaved, lastSaved.reminderAt != nil {
                await notificationService.cancel(id: lastSaved.id)
            }
        default:
            if undoManager.hasDiscard, let text = undoManager.lastDiscardText {
                let inlineTags = InlineTagExtractor.extract(from: text)
                if let restored = try? undoManager.restoreDiscard(repository: repository, inlineTags: inlineTags) {
                    await reminderHandler(restored)
                    setFeedback("破棄を元に戻しました")
                    lastAction = .restoredDiscard
                }
            }
        }
    }

    private func validateReminderQuotaIfNeeded(reminder: Date?) throws {
        // 制限なし - 全機能無料開放
    }

    private func format(reminder: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: reminder)
    }
}

enum WriteError: Error {
    case reminderQuotaReached
}

private enum LastAction {
    case none
    case saved
    case savedWithReminder
    case discarded
    case restoredDiscard
    case undidSave
}

#if !canImport(UIKit)
private struct HapticFallback {
    func impactOccurred() {}
}
#endif

// MARK: - Feedback helper
extension WriteViewModel {
    private func setFeedback(_ message: String?) {
        feedbackMessage = message
        guard let message else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if feedbackMessage == message {
                feedbackMessage = nil
            }
        }
    }
}
