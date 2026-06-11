// ViewModels/RecipeListViewModel.swift

import Foundation
import Combine

// MARK: - RecipeListViewModel

/// Drives RecipeListView — the single source of truth for the recipe list screen.
///
/// Design notes:
///   - `@MainActor` ensures every `@Published` mutation happens on the main thread,
///     which is required by SwiftUI and ObservableObject.
///   - Business logic (filter, paginate, cache) lives here; views stay declarative.
///   - Dependencies are injected so the ViewModel is fully unit-testable without
///     a real network connection or CoreData store.
@MainActor
final class RecipeListViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String? = nil
    @Published private(set) var isOffline: Bool = false
    @Published private(set) var hasNextPage: Bool = false
    @Published private(set) var allIngredientNames: [String] = []

    // Favorites state — forwarded from FavoritesService via Combine.
    // Views read these directly; no @EnvironmentObject needed anywhere.
    @Published private(set) var favoriteRecipes: [Recipe] = []
    @Published private(set) var favoriteIDs: Set<String> = []

    /// Two-way binding: the View edits `filter`; the ViewModel observes and reacts.
    @Published var filter: RecipeFilter = RecipeFilter()

    // MARK: - Private State

    private var currentPage: Int = 1
    private let pageSize: Int

    // MARK: - Dependencies

    private let recipeService: RecipeServiceProtocol
    private let persistenceService: RecipePersistenceServiceProtocol
    private let connectivityMonitor: ConnectivityMonitor
    private let favoritesService: any FavoritesServiceProtocol

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        recipeService: RecipeServiceProtocol = RecipeService(),
        persistenceService: RecipePersistenceServiceProtocol = RecipePersistenceService(),
        connectivityMonitor: ConnectivityMonitor = ConnectivityMonitor(),
        favoritesService: any FavoritesServiceProtocol = FavoritesService.shared,
        pageSize: Int = 10
    ) {
        self.recipeService = recipeService
        self.persistenceService = persistenceService
        self.connectivityMonitor = connectivityMonitor
        self.favoritesService = favoritesService
        self.pageSize = pageSize

        bindConnectivity()
        bindFilterChanges()
        bindFavoritesChanges()
    }

    // MARK: - Public API

    /// Initial or pull-to-refresh load. Resets pagination.
    func loadRecipes() async {
        await fetch(reset: true)
        if allIngredientNames.isEmpty {
            await prefetchIngredientNames()
        }
    }

    /// Appends the next page when the user scrolls to the end of the list.
    func loadNextPageIfNeeded(currentItem recipe: Recipe) async {
        guard hasNextPage, !isLoading else { return }
        guard let lastID = recipes.last?.id, lastID == recipe.id else { return }
        await fetch(reset: false)
    }

    /// Clears the active error banner.
    func dismissError() {
        errorMessage = nil
    }

    /// O(1) check whether a recipe is currently favorited.
    func isFavorite(_ id: String) -> Bool {
        favoriteIDs.contains(id)
    }

    /// Toggles the favorite state of a recipe, persisting to CoreData via FavoritesService.
    func toggleFavorite(_ recipe: Recipe) async {
        await favoritesService.toggle(recipe)
    }

    // MARK: - Private

    private func fetch(reset: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        if reset {
            currentPage = 1
        }

        defer { isLoading = false }

        do {
            let response: PaginatedResponse<Recipe>
            if filter.isActive {
                response = try await recipeService.searchRecipes(
                    filter: filter,
                    page: currentPage,
                    pageSize: pageSize
                )
            } else {
                response = try await recipeService.fetchRecipes(
                    page: currentPage,
                    pageSize: pageSize
                )
                // Cache only on unfiltered full-page fetches to keep the
                // offline store representative of the whole dataset.
                try? await persistenceService.save(response.data)
            }

            if reset {
                recipes = response.data
            } else {
                recipes += response.data
            }

            hasNextPage = response.hasNextPage
            currentPage = response.page + 1

        } catch {
            errorMessage = error.localizedDescription
            if recipes.isEmpty {
                await loadCachedRecipes()
            }
        }
    }

    /// Fetches all recipes at once to build the ingredient suggestion list.
    /// Runs after initial load; non-critical so failures are silently ignored.
    private func prefetchIngredientNames() async {
        do {
            let response = try await recipeService.fetchRecipes(page: 1, pageSize: 1000)
            allIngredientNames = RecipeService.allIngredientNames(from: response.data)
        } catch {
            // Non-critical — filter chips just won't appear
        }
    }

    /// Falls back to CoreData cache when the network fails.
    private func loadCachedRecipes() async {
        guard let cached = try? await persistenceService.fetchAll(), !cached.isEmpty else { return }
        recipes = cached
        hasNextPage = false
    }

    // MARK: - Combine bindings

    private func bindConnectivity() {
        connectivityMonitor.$isConnected
            .map { !$0 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOffline)
    }

    /// Bridges FavoritesService publishers into @Published properties on this ViewModel
    /// so views only observe one object instead of reaching into a separate service.
    private func bindFavoritesChanges() {
        favoritesService.favoritesPublisher
            .assign(to: &$favoriteRecipes)
        favoritesService.favoriteIDsPublisher
            .assign(to: &$favoriteIDs)
    }

    /// Debounces filter changes so we don't fire a fetch on every keystroke.
    private func bindFilterChanges() {
        $filter
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.fetch(reset: true) }
            }
            .store(in: &cancellables)
    }
}
