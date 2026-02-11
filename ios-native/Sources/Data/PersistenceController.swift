import CoreData

final class PersistenceController {
    static let shared = PersistenceController()
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        for idx in 0..<10 {
            let memo = MemoEntity(context: context)
            memo.id = Int64(idx + 1)
            memo.text = "Preview memo \(idx + 1)"
            memo.createdAt = Date().addingTimeInterval(TimeInterval(-idx * 600))
            memo.updatedAt = memo.createdAt
            memo.reminderAt = idx % 3 == 0 ? Date().addingTimeInterval(TimeInterval(idx * 1800)) : nil
            memo.isDone = idx % 4 == 0
            memo.inlineTags = ["sample", "preview"]
        }
        try? context.save()
        return controller
    }()

    static func makeInMemory() -> PersistenceController {
        PersistenceController(inMemory: true)
    }

    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        let model = MemoEntity.managedObjectModel()
        container = NSPersistentContainer(name: "KotoModel", managedObjectModel: model)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        } else {
            let storeURL = Self.storeURL()
            let description = NSPersistentStoreDescription(url: storeURL)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Unresolved Core Data error \(error)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func storeURL() -> URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let directory = urls.first ?? FileManager.default.temporaryDirectory
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("Koto.sqlite")
    }

    func saveContext() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            assertionFailure("Failed to save context: \(error)")
        }
    }
}
