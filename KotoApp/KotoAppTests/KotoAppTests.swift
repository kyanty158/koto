import XCTest
import KotoKit

final class KotoAppTests: XCTestCase {
    func testAppSceneInitializesEnvironment() {
        let scene = KotoAppScene()
        XCTAssertNotNil(scene.body, "KotoAppScene should provide a window group scene.")
    }
}
