import CoreData
import Combine

@MainActor
final class MemoRepository {
    private let container: NSPersistentContainer

    init(container: NSPersistentContainer) {
        self.container = container
        resetAutoIncrementBaseline()
    }

    private var context: NSManagedObjectContext {
        container.viewContext
    }

    func createMemo(text: String, reminderAt: Date?, inlineTags: [String]) throws -> MemoModel {
        let memo = MemoEntity(context: context)
        memo.id = AutoIncrementer.nextID()
        memo.text = text
        memo.createdAt = Date()
        memo.updatedAt = memo.createdAt
        memo.reminderAt = reminderAt
        memo.isDone = false
        memo.inlineTags = inlineTags
        try save()
        return MemoModel(entity: memo)
    }

    func updateMemo(_ memoModel: MemoModel) throws -> MemoModel {
        let request = MemoEntity.fetchRequest(id: memoModel.id)
        guard let entity = try context.fetch(request).first else {
            throw RepositoryError.missingMemo
        }
        entity.text = memoModel.text
        entity.updatedAt = Date()
        entity.reminderAt = memoModel.reminderAt
        entity.isDone = memoModel.isDone
        entity.inlineTags = memoModel.inlineTags
        try save()
        return MemoModel(entity: entity)
    }

    func markDone(id: Int64, done: Bool) throws {
        let request = MemoEntity.fetchRequest(id: id)
        guard let entity = try context.fetch(request).first else { return }
        entity.isDone = done
        entity.updatedAt = Date()
        try save()
    }

    func delete(ids: [Int64]) throws {
        guard !ids.isEmpty else { return }
        let request = MemoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids)
        let results = try context.fetch(request)
        results.forEach { context.delete($0) }
        try save()
    }

    func memo(for id: Int64) throws -> MemoModel? {
        let request = MemoEntity.fetchRequest(id: id)
        return try context.fetch(request).first.map(MemoModel.init(entity:))
    }

    func reminderCount(for month: Date) throws -> Int {
        let calendar = Calendar(identifier: .gregorian)
        guard
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
            let nextMonth = calendar.date(byAdding: DateComponents(month: 1), to: monthStart)
        else { return 0 }

        let request = MemoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "reminderAt >= %@ AND reminderAt < %@", monthStart as NSDate, nextMonth as NSDate)
        return try context.count(for: request)
    }

    func upcomingReminders(limit: Int = 6) throws -> [MemoModel] {
        let request = MemoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "reminderAt != nil AND reminderAt > %@ AND isDone == NO", Date() as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(key: "reminderAt", ascending: true)
        ]
        request.fetchLimit = limit
        let entities = try context.fetch(request)
        return entities.map(MemoModel.init(entity:))
    }

    func fetchedResultsController(searchTerm: String?, limit: Int?) -> NSFetchedResultsController<MemoEntity> {
        let request = MemoEntity.fetchRequest()
        var predicates: [NSPredicate] = []
        if let searchTerm, !searchTerm.isEmpty {
            if searchTerm.hasPrefix("#") {
                let tag = String(searchTerm.dropFirst()).lowercased()
                predicates.append(NSPredicate(format: "ANY inlineTags == %@", tag))
            } else {
                predicates.append(NSPredicate(format: "text CONTAINS[cd] %@", searchTerm))
            }
        }
        request.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        if let limit {
            request.fetchLimit = limit
        }
        let frc = NSFetchedResultsController(fetchRequest: request,
                                             managedObjectContext: context,
                                             sectionNameKeyPath: nil,
                                             cacheName: nil)
        try? frc.performFetch()
        return frc
    }

    private func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }

    private func resetAutoIncrementBaseline() {
        let request = MemoEntity.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        if let maxId = try? context.fetch(request).first?.id {
            AutoIncrementer.resetIfNeeded(to: maxId)
        }
    }
}

enum RepositoryError: Error {
    case missingMemo
}
