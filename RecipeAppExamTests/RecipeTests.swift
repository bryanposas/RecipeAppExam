import XCTest
import SwiftData
@testable import RecipeAppExam

final class RecipeTests: XCTestCase {

    func testRecipeModelInit() throws {
        let r = Recipe(name: "Test", summary: "Summary")
        XCTAssertEqual(r.name, "Test")
        XCTAssertEqual(r.summary, "Summary")
        XCTAssertNotNil(r.id)
    }

}
