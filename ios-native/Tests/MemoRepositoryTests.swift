import XCTest
@testable import KotoKit

private final class StubNotificationService: NotificationScheduling {
    func schedule(id: Int64, when: Date, title: String, body: String) async throws {}
    func cancel(id: Int64) async {}
}

@MainActor
final class MemoRepositoryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "MemoAutoIncrement")
    }

    func testCreateUpdateDeleteMemo() throws {
        let persistence = PersistenceController.makeInMemory()
        let repository = MemoRepository(container: persistence.container)

        var memo = try repository.createMemo(text: "First memo", reminderAt: nil, inlineTags: [])
        XCTAssertEqual(memo.text, "First memo")
        XCTAssertFalse(memo.isDone)

        memo.text = "Updated memo"
        memo.inlineTags = ["updated"]
        memo.isDone = true

        let updated = try repository.updateMemo(memo)
        XCTAssertEqual(updated.text, "Updated memo")
        XCTAssertTrue(updated.isDone)
        XCTAssertEqual(updated.inlineTags, ["updated"])

        let fetched = try repository.memo(for: updated.id)
        XCTAssertEqual(fetched?.text, "Updated memo")

        try repository.delete(ids: [updated.id])
        XCTAssertNil(try repository.memo(for: updated.id))
    }


}
