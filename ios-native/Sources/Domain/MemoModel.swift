import Foundation

struct MemoModel: Identifiable, Hashable {
    let id: Int64
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var reminderAt: Date?
    var isDone: Bool
    var inlineTags: [String]

    var isReminderActive: Bool {
        guard let reminderAt else { return false }
        return reminderAt > Date()
    }

    var displayTextForReminder: String? {
        guard let reminderAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: reminderAt)
    }
}

extension MemoModel {
    init(entity: MemoEntity) {
        id = entity.id
        text = entity.text
        createdAt = entity.createdAt
        updatedAt = entity.updatedAt
        reminderAt = entity.reminderAt
        isDone = entity.isDone
        inlineTags = entity.inlineTags
    }
}
