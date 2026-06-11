// RecipeListViewModelTests.swift

import Foundation
import Testing
@testable import RecipeAppExam

// MARK: - Suite: Recipe List ViewModel

@Suite("Recipe List ViewModel")
struct RecipeListViewModelTests {

    // MARK: - Initial state

    @Test("Initial state: recipes are empty, isLoading is false, no error, no next page")
    @MainActor
    func initialState() {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: [])),
            persistenceService: StubPersistenceService()
        )
        #expect(sut.recipes.isEmpty)
        #expect(!sut.isLoading)
        #expect(sut.errorMessage == nil)
        #expect(!sut.hasNextPage)
        #expect(sut.allIngredientNames.isEmpty)
    }

    // MARK: - loadRecipes

    @Test("loadRecipes populates the recipes array from the service")
    @MainActor
    func loadRecipesPopulatesRecipes() async {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes)),
            persistenceService: StubPersistenceService()
        )
        await sut.loadRecipes()
        #expect(!sut.recipes.isEmpty)
        #expect(sut.recipes.count == Fixtures.sampleRecipes.count)
    }

    @Test("loadRecipes with fewer results than pageSize leaves hasNextPage false")
    @MainActor
    func loadRecipesNoNextPageWhenUnderPageSize() async {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes)),
            persistenceService: StubPersistenceService(),
            pageSize: 10
        )
        await sut.loadRecipes()
        #expect(!sut.hasNextPage)
    }

    @Test("loadRecipes with more results than pageSize sets hasNextPage true")
    @MainActor
    func loadRecipesHasNextPageWhenOverPageSize() async {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: Fixtures.twentyRecipes)),
            persistenceService: StubPersistenceService(),
            pageSize: 5
        )
        await sut.loadRecipes()
        #expect(sut.hasNextPage)
        #expect(sut.recipes.count == 5)
    }

    @Test("loadRecipes populates allIngredientNames from the full dataset")
    @MainActor
    func loadRecipesPopulatesIngredientNames() async {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes)),
            persistenceService: StubPersistenceService()
        )
        await sut.loadRecipes()
        #expect(!sut.allIngredientNames.isEmpty)
        #expect(sut.allIngredientNames == sut.allIngredientNames.sorted())
    }

    @Test("Calling loadRecipes a second time resets to page 1 and refreshes results")
    @MainActor
    func loadRecipesResetsOnSecondCall() async {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes)),
            persistenceService: StubPersistenceService()
        )
        await sut.loadRecipes()
        let firstCount = sut.recipes.count

        await sut.loadRecipes()
        #expect(sut.recipes.count == firstCount)
    }

    // MARK: - Pagination

    @Test("loadNextPageIfNeeded for the last recipe appends the next page")
    @MainActor
    func loadNextPageIfNeededAppendsForLastRecipe() async {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: Fixtures.twentyRecipes)),
            persistenceService: StubPersistenceService(),
            pageSize: 5
        )
        await sut.loadRecipes()
        #expect(sut.recipes.count == 5)

        let last = try! #require(sut.recipes.last)
        await sut.loadNextPageIfNeeded(currentItem: last)

        #expect(sut.recipes.count == 10)
    }

    @Test("loadNextPageIfNeeded for a non-last recipe does not trigger a fetch")
    @MainActor
    func loadNextPageIfNeededIgnoresNonLastRecipe() async {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: Fixtures.twentyRecipes)),
            persistenceService: StubPersistenceService(),
            pageSize: 5
        )
        await sut.loadRecipes()
        let first = sut.recipes[0]

        await sut.loadNextPageIfNeeded(currentItem: first)

        #expect(sut.recipes.count == 5)
    }

    @Test("loadNextPageIfNeeded when hasNextPage is false does nothing")
    @MainActor
    func loadNextPageIfNeededNoOpWhenNoNextPage() async {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes)),
            persistenceService: StubPersistenceService()
        )
        await sut.loadRecipes()
        #expect(!sut.hasNextPage)

        let last = try! #require(sut.recipes.last)
        await sut.loadNextPageIfNeeded(currentItem: last)

        #expect(sut.recipes.count == Fixtures.sampleRecipes.count)
    }

    // MARK: - Error handling

    @Test("loadRecipes with a failing service sets errorMessage")
    @MainActor
    func loadRecipesWithFailingServiceSetsError() async {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: FailingNetworkService()),
            persistenceService: StubPersistenceService()
        )
        await sut.loadRecipes()
        #expect(sut.errorMessage != nil)
    }

    @Test("dismissError clears a previously set error message")
    @MainActor
    func dismissErrorClearsMessage() async {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: FailingNetworkService()),
            persistenceService: StubPersistenceService()
        )
        await sut.loadRecipes()
        #expect(sut.errorMessage != nil)

        sut.dismissError()
        #expect(sut.errorMessage == nil)
    }

    @Test("loadRecipes with a failing service falls back to cached recipes when available")
    @MainActor
    func loadRecipesFallsBackToCacheOnError() async {
        let cache = StubPersistenceService()
        try! await cache.save(Fixtures.sampleRecipes)

        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: FailingNetworkService()),
            persistenceService: cache
        )
        await sut.loadRecipes()

        #expect(!sut.recipes.isEmpty)
        #expect(sut.recipes.count == Fixtures.sampleRecipes.count)
    }

    // MARK: - Filter

    @Test("Setting a filter and reloading returns only matching recipes")
    @MainActor
    func filteringReducesResults() async {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes)),
            persistenceService: StubPersistenceService()
        )
        await sut.loadRecipes()
        let unfilteredCount = sut.recipes.count

        sut.filter.dietaryAttributes = ["vegan"]
        await sut.loadRecipes()

        #expect(sut.recipes.count < unfilteredCount)
        #expect(sut.recipes.allSatisfy { $0.dietaryAttributes.contains("vegan") })
    }

    // MARK: - Favorites via explicit DI

    @Test("isFavorite returns false for any recipe before any toggle")
    @MainActor
    func viewModelIsFavoriteInitiallyFalse() {
        let mock = MockFavoritesService()
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: [])),
            persistenceService: StubPersistenceService(),
            favoritesService: mock
        )
        #expect(!sut.isFavorite(Fixtures.sampleRecipes[0].id))
        #expect(sut.favoriteIDs.isEmpty)
        #expect(sut.favoriteRecipes.isEmpty)
    }

    @Test("toggleFavorite adds the recipe to favoriteIDs and favoriteRecipes")
    @MainActor
    func viewModelToggleFavoriteAddsRecipe() async {
        let mock = MockFavoritesService()
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: [])),
            persistenceService: StubPersistenceService(),
            favoritesService: mock
        )
        let recipe = Fixtures.sampleRecipes[0]

        await sut.toggleFavorite(recipe)

        #expect(sut.isFavorite(recipe.id))
        #expect(sut.favoriteIDs.contains(recipe.id))
        #expect(sut.favoriteRecipes.count == 1)
    }

    @Test("Toggling the same recipe twice removes it from favoriteIDs and favoriteRecipes")
    @MainActor
    func viewModelToggleFavoriteTwiceRemovesRecipe() async {
        let mock = MockFavoritesService()
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: [])),
            persistenceService: StubPersistenceService(),
            favoritesService: mock
        )
        let recipe = Fixtures.sampleRecipes[0]

        await sut.toggleFavorite(recipe)
        await sut.toggleFavorite(recipe)

        #expect(!sut.isFavorite(recipe.id))
        #expect(sut.favoriteIDs.isEmpty)
        #expect(sut.favoriteRecipes.isEmpty)
    }

    @Test("favoriteIDs and favoriteRecipes reflect independent toggles for multiple recipes")
    @MainActor
    func viewModelMultipleTogglesReflectedCorrectly() async {
        let mock = MockFavoritesService()
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: [])),
            persistenceService: StubPersistenceService(),
            favoritesService: mock
        )
        let r1 = Fixtures.sampleRecipes[0]
        let r2 = Fixtures.sampleRecipes[1]

        await sut.toggleFavorite(r1)
        await sut.toggleFavorite(r2)

        #expect(sut.favoriteIDs.count == 2)
        #expect(sut.favoriteRecipes.count == 2)

        await sut.toggleFavorite(r1)

        #expect(sut.favoriteIDs.count == 1)
        #expect(!sut.isFavorite(r1.id))
        #expect(sut.isFavorite(r2.id))
        #expect(sut.favoriteRecipes.count == 1)
    }

    @Test("ViewModel favoriteIDs stay in sync with the injected FavoritesService")
    @MainActor
    func viewModelFavoriteIDsReflectServiceState() async {
        let mock = MockFavoritesService()
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: MockNetworkService(recipes: [])),
            persistenceService: StubPersistenceService(),
            favoritesService: mock
        )
        let recipe = Fixtures.sampleRecipes[2]

        await sut.toggleFavorite(recipe)

        #expect(sut.favoriteIDs == mock.favoriteIDs)
        #expect(sut.favoriteRecipes.map(\.id) == mock.favorites.map(\.id))
    }
}
