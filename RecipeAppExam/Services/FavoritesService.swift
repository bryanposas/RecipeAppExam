// Services/FavoritesService.swift

import Foundation

// MARK: - FavoritesService

/// Persists favorited recipes across app restarts via UserDefaults.
/// Full Recipe objects are stored so favorites remain usable without a network connection.
@MainActor
final class FavoritesService: ObservableObject {

    static let shared = FavoritesService()

    @Published private(set) var favorites: [Recipe] = []

    private let storageKey = "com.recipeapp.favorites"
    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Testing Factories

    /// Creates an isolated instance backed by a fresh temporary UserDefaults suite.
    static func makeForTesting() -> FavoritesService {
        FavoritesService(defaults: UserDefaults(suiteName: "com.recipeapp.test.\(UUID().uuidString)")!)
    }

    /// Creates an isolated instance backed by the provided UserDefaults.
    /// Use this when two instances must share the same store (persistence tests).
    static func makeForTesting(defaults: UserDefaults) -> FavoritesService {
        FavoritesService(defaults: defaults)
    }

    // MARK: - Public API

    func toggle(_ recipe: Recipe) {
        if let index = favorites.firstIndex(where: { $0.id == recipe.id }) {
            favorites.remove(at: index)
        } else {
            favorites.append(recipe)
        }
        save()
    }

    func isFavorite(_ id: String) -> Bool {
        favorites.contains { $0.id == id }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Recipe].self, from: data) else { return }
        favorites = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
