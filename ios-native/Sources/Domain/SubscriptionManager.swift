import Foundation

/// サブスクリプション管理（全機能無料開放版）
@MainActor
final class SubscriptionManager: ObservableObject {
    
    // 常にすべての機能が使える
    var reminderMonthlyLimit: Int { .max }
    var maxVisibleMemos: Int? { nil }
    var canSearch: Bool { true }
    
    init() {}
}
