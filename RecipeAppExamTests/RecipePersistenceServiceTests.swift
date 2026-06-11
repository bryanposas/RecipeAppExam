// RecipePersistenceServiceTests.swift

import Foundation
import Testing
@testable import RecipeAppExam

// MARK: - Suite: Recipe Persistence

/// Each `@Test` receives a fresh struct instance, so `init()` runs before
/// every test — each gets its own isolated in-memory CoreData stack.
@Suite("Recipe Persistence")
struct RecipePersistenceServiceTests {

    private let sut: RecipePersistenceService

    init() {
        sut = RecipePersistenceService(coreDataStack: CoreDataStack(inMemory: true))
    }

    @Test("Saved recipes are retrievable via fetchAll")
    func saveAndFetchAll() async throws {
        let recipes = [Fixtures.sampleRecipes[0], Fixtures.sampleRecipes[1]]
        try await sut.save(recipes)

        let fetched = try await sut.fetchAll()

        #expect(fetched.count == 2)
    }

    @Test("dietaryAttributes are preserved through the CoreData round-trip")
    func dietaryAttributesRoundTrip() async throws {
        let original = Fixtures.sampleRecipes[2] // has vegan, vegetarian, plant-based, dairy-free
        try await sut.save([original])

        let fetched = try await sut.fetchAll()
        let first = try #require(fetched.first)

        #expect(first.dietaryAttributes.sorted() == original.dietaryAttributes.sorted())
    }

    @Test("Saving a recipe with an existing ID updates the record without duplicating it")
    func upsertsByID() async throws {
        let original = Fixtures.sampleRecipes[0]
        try await sut.save([original])

        let updated = Recipe(
            id: original.id,
            title: "Updated Title",
            description: original.description,
            servings: original.servings,
            ingredients: original.ingredients,
            instructions: original.instructions,
            dietaryAttributes: ["vegan", "gluten-free"],
            imageURL: original.imageURL
        )
        try await sut.save([updated])

        let fetched = try await sut.fetchAll()
        #expect(fetched.count == 1)

        let first = try #require(fetched.first)
        #expect(first.title == "Updated Title")
        #expect(first.dietaryAttributes.sorted() == ["gluten-free", "vegan"])
    }

    @Test("deleteAll removes every recipe from the persistent store")
    func deleteAll() async throws {
        try await sut.save(Fixtures.sampleRecipes)
        try await sut.deleteAll()

        let fetched = try await sut.fetchAll()

        #expect(fetched.isEmpty)
    }

    @Test("fetchAll returns recipes sorted alphabetically by title")
    func fetchAllSortedByTitle() async throws {
        try await sut.save(Fixtures.sampleRecipes)

        let fetched = try await sut.fetchAll()
        let titles = fetched.map(\.title)

        #expect(titles == titles.sorted())
    }

    @Test("imageURL is preserved through the CoreData round-trip")
    func imageURLRoundTrip() async throws {
        let original = Recipe(
            id: "img-test",
            title: "Image Test Recipe",
            description: "A recipe with an image",
            servings: 2,
            ingredients: ["flour"],
            instructions: ["mix"],
            dietaryAttributes: [],
            imageURL: "https://picsum.photos/seed/test/800/600"
        )
        try await sut.save([original])

        let fetched = try await sut.fetchAll()
        let first = try #require(fetched.first)

        #expect(first.imageURL == original.imageURL)
    }
}
