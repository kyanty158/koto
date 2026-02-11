import CoreData

@objc(MemoEntity)
final class MemoEntity: NSManagedObject {
    @NSManaged var id: Int64
    @NSManaged var text: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var reminderAt: Date?
    @NSManaged var isDone: Bool
    @NSManaged var inlineTags: [String]
}

extension MemoEntity {
    @nonobjc
    static func fetchRequest() -> NSFetchRequest<MemoEntity> {
        NSFetchRequest<MemoEntity>(entityName: "MemoEntity")
    }

    @nonobjc
    static func fetchRequest(id: Int64) -> NSFetchRequest<MemoEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %lld", id)
        request.fetchLimit = 1
        return request
    }
}

// MARK: - Managed Object Model

extension MemoEntity {
    /// Builds an in-memory `.momd` equivalent so that we can ship without Xcode .xcdatamodeld.
    static func managedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "MemoEntity"
        entity.managedObjectClassName = NSStringFromClass(MemoEntity.self)
        entity.isAbstract = false

        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .integer64AttributeType
        idAttr.isOptional = false
        idAttr.defaultValue = 0

        let textAttr = NSAttributeDescription()
        textAttr.name = "text"
        textAttr.attributeType = .stringAttributeType
        textAttr.isOptional = false

        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false

        let updatedAtAttr = NSAttributeDescription()
        updatedAtAttr.name = "updatedAt"
        updatedAtAttr.attributeType = .dateAttributeType
        updatedAtAttr.isOptional = false

        let reminderAtAttr = NSAttributeDescription()
        reminderAtAttr.name = "reminderAt"
        reminderAtAttr.attributeType = .dateAttributeType
        reminderAtAttr.isOptional = true

        let isDoneAttr = NSAttributeDescription()
        isDoneAttr.name = "isDone"
        isDoneAttr.attributeType = .booleanAttributeType
        isDoneAttr.isOptional = false
        isDoneAttr.defaultValue = false

        let inlineTagsAttr = NSAttributeDescription()
        inlineTagsAttr.name = "inlineTags"
        inlineTagsAttr.attributeType = .transformableAttributeType
        inlineTagsAttr.valueTransformerName = NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue
        inlineTagsAttr.attributeValueClassName = NSStringFromClass(NSArray.self)
        inlineTagsAttr.isOptional = false
        inlineTagsAttr.defaultValue = []

        entity.properties = [
            idAttr,
            textAttr,
            createdAtAttr,
            updatedAtAttr,
            reminderAtAttr,
            isDoneAttr,
            inlineTagsAttr
        ]

        entity.uniquenessConstraints = [["id"]]

        model.entities = [entity]
        return model
    }
}
