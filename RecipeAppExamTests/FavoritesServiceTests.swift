// FavoritesServiceTests.swift

import Foundation
import Testing
@testable import RecipeAppExam

// MARK: - Suite: Favorites Service

@Suite("Favorites Service")
struct FavoritesServiceTests {

    @Test("isFavorite returns false for a recipe that has never been toggled")
    @MainActor
    func isFavoriteReturnsFalseForUnknownID() {
        let sut = FavoritesService.makeForTesting()
        #expect(!sut.isFavorite("nonexistent-id"))
    }

    @Test("toggle adds a recipe to the favorites list")
    @MainActor
    func toggleAddsRecipe() async {
        let sut = FavoritesService.makeForTesting()
        let recipe = Fixtures.sampleRecipes[0]

        await sut.toggle(recipe)

        #expect(sut.favoriteIDs.count == 1)
        #expect(sut.isFavorite(recipe.id))
    }

    @Test("Toggling a recipe that is already a favorite removes it")
    @MainActor
    func toggleTwiceRemovesRecipe() async {
        let sut = FavoritesService.makeForTesting()
        let recipe = Fixtures.sampleRecipes[0]

        await sut.toggle(recipe)
        await sut.toggle(recipe)

        #expect(sut.favoriteIDs.isEmpty)
        #expect(!sut.isFavorite(recipe.id))
    }

    @Test("Multiple distinct recipes can each be favorited independently")
    @MainActor
    func multipleRecipesFavoritedAndCounted() async {
        let sut = FavoritesService.makeForTesting()
        let r1 = Fixtures.sampleRecipes[0]
        let r2 = Fixtures.sampleRecipes[1]
        let r3 = Fixtures.sampleRecipes[2]

        await sut.toggle(r1)
        await sut.toggle(r2)
        await sut.toggle(r3)
        #expect(sut.favoriteIDs.count == 3)

        await sut.toggle(r2)
        #expect(sut.favoriteIDs.count == 2)
        #expect(sut.isFavorite(r1.id))
        #expect(!sut.isFavorite(r2.id))
        #expect(sut.isFavorite(r3.id))
    }

    @Test("Favorites written by one instance are visible to a second instance sharing the same CoreData stack")
    @MainActor
    func favoritesPersistedAndReloadedBySecondInstance() async {
        let sharedStack = CoreDataStack(inMemory: true)

        let writer = FavoritesService.makeForTesting(coreDataStack: sharedStack)
        await writer.toggle(Fixtures.sampleRecipes[0])
        await writer.toggle(Fixtures.sampleRecipes[1])

        let reader = FavoritesService.makeForTesting(coreDataStack: sharedStack)
        await reader.loadFavorites()

        #expect(reader.favoriteIDs.count == 2)
        #expect(reader.isFavorite(Fixtures.sampleRecipes[0].id))
        #expect(reader.isFavorite(Fixtures.sampleRecipes[1].id))
    }

    @Test("A fresh instance starts with an empty favorites list")
    @MainActor
    func freshInstanceHasNoFavorites() {
        let sut = FavoritesService.makeForTesting()
        #expect(sut.favorites.isEmpty)
        #expect(sut.favoriteIDs.isEmpty)
    }
}
