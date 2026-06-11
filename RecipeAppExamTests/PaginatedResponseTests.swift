// PaginatedResponseTests.swift

import Foundation
import Testing
@testable import RecipeAppExam

// MARK: - Suite: Paginated Response

@Suite("Paginated Response")
struct PaginatedResponseTests {

    @Test(
        "hasNextPage is accurate across different page positions in a two-page set",
        arguments: zip([1, 2], [true, false])
    )
    func hasNextPage(page: Int, expected: Bool) {
        let response = PaginatedResponse<Recipe>(
            data: [],
            page: page,
            pageSize: 10,
            totalCount: 20,
            totalPages: 2
        )
        #expect(response.hasNextPage == expected)
    }

    @Test("Single-page result always has no next page")
    func singlePageHasNoNextPage() {
        let response = PaginatedResponse<Recipe>(
            data: [],
            page: 1,
            pageSize: 10,
            totalCount: 5,
            totalPages: 1
        )
        #expect(!response.hasNextPage)
    }

    @Test("totalPages is correctly reflected in the response metadata")
    func totalPagesMetadata() {
        let response = PaginatedResponse<Recipe>(
            data: [],
            page: 1,
            pageSize: 5,
            totalCount: 20,
            totalPages: 4
        )
        #expect(response.totalPages == 4)
        #expect(response.totalCount == 20)
        #expect(response.pageSize == 5)
    }
}
