// Models/PaginatedResponse.swift

import Foundation

// MARK: - PaginatedResponse

/// Generic wrapper for paginated API responses.
/// Mirrors the shape a real REST endpoint would return so the service layer
/// can swap mock vs. live implementations without changing callers.
struct PaginatedResponse<T: Codable>: Codable {

    let data: [T]
    let page: Int
    let pageSize: Int
    let totalCount: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case data
        case page
        case pageSize = "page_size"
        case totalCount = "total_count"
        case totalPages = "total_pages"
    }

    /// Convenience to determine whether a subsequent page exists.
    var hasNextPage: Bool { page < totalPages }
}
