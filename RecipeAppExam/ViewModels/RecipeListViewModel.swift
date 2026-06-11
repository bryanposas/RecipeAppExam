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

    /// Two-way binding: the View edits `filter`; the ViewModel observes and reacts.
    @Published var filter: RecipeFilter = RecipeFilter()

    // MARK: - Private State

    private var currentPage: Int = 1
    private let pageSize: Int = 10

    // MARK: - Dependencies

    private let recipeService: RecipeServiceProtocol
    private let persistenceService: RecipePersistenceServiceProtocol
    private let connectivityMonitor: ConnectivityMonitor

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        recipeService: RecipeServiceProtocol = RecipeService(),
        persistenceService: RecipePersistenceServiceProtocol = RecipePersistenceService(),
        connectivityMonitor: ConnectivityMonitor = ConnectivityMonitor()
    ) {
        self.recipeService = recipeService
        self.persistenceService = persistenceService
        self.connectivityMonitor = connectivityMonitor

        bindConnectivity()
        bindFilterChanges()
    }

    // MARK: - Public API

    /// Initial or pull-to-refresh load. Resets pagination.
    func loadRecipes() async {
        await fetch(reset: true)
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
