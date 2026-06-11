// Support/Mocks.swift

import Combine
import Foundation
@testable import RecipeAppExam

// MARK: - MockNetworkService

struct MockNetworkService: NetworkServiceProtocol {
    let recipes: [Recipe]

    func fetch<T: Decodable & Sendable>(endpoint: APIEndpoint) async throws -> T {
        guard let result = recipes as? T else {
            throw NetworkError.resourceNotFound("stub")
        }
        return result
    }
}

// MARK: - FailingNetworkService

struct FailingNetworkService: NetworkServiceProtocol {
    func fetch<T: Decodable & Sendable>(endpoint: APIEndpoint) async throws -> T {
        throw NetworkError.networkUnavailable
    }
}

// MARK: - StubPersistenceService

final class StubPersistenceService: RecipePersistenceServiceProtocol, @unchecked Sendable {
    private var stored: [Recipe] = []

    func save(_ recipes: [Recipe]) async throws { stored = recipes }
    func fetchAll() async throws -> [Recipe] { stored }
    func deleteAll() async throws { stored = [] }
}

// MARK: - MockFavoritesService

/// Lightweight in-memory mock that satisfies FavoritesServiceProtocol.
/// Uses CurrentValueSubject so ViewModel subscribers see changes immediately.
@MainActor
final class MockFavoritesService: FavoritesServiceProtocol {

    private var _favorites: [Recipe] = [] {
        didSet { favoritesSubject.send(_favorites) }
    }
    private var _favoriteIDs: Set<String> = [] {
        didSet { favoriteIDsSubject.send(_favoriteIDs) }
    }

    private let favoritesSubject = CurrentValueSubject<[Recipe], Never>([])
    private let favoriteIDsSubject = CurrentValueSubject<Set<String>, Never>([])

    var favorites: [Recipe] { _favorites }
    var favoriteIDs: Set<String> { _favoriteIDs }

    var favoritesPublisher: AnyPublisher<[Recipe], Never> {
        favoritesSubject.eraseToAnyPublisher()
    }

    var favoriteIDsPublisher: AnyPublisher<Set<String>, Never> {
        favoriteIDsSubject.eraseToAnyPublisher()
    }

    func toggle(_ recipe: Recipe) async {
        if _favoriteIDs.contains(recipe.id) {
            _favoriteIDs.remove(recipe.id)
            _favorites.removeAll { $0.id == recipe.id }
        } else {
            _favoriteIDs.insert(recipe.id)
            _favorites.append(recipe)
        }
    }

    func isFavorite(_ id: String) -> Bool { _favoriteIDs.contains(id) }

    func loadFavorites() async {}
}
