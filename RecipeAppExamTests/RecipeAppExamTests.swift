// RecipeAppExamTests.swift

import Testing
@testable import RecipeAppExam

// MARK: - Shared fixtures

private enum Fixtures {
    static let sampleRecipes: [Recipe] = [
        Recipe(
            id: "1",
            title: "Pizza Recipe 1",
            description: "Delicious recipe",
            servings: 4,
            ingredients: ["flour", "tomato", "mozzarella"],
            instructions: ["Step 1", "Step 2"],
            dietaryAttributes: ["vegetarian", "nut-free"],
            imageURL: nil
        ),
        Recipe(
            id: "2",
            title: "Curry Recipe 2",
            description: "Spiced recipe",
            servings: 4,
            ingredients: ["chicken", "tomato", "cream"],
            instructions: ["Step 1", "Step 2"],
            dietaryAttributes: ["gluten-free", "halal", "nut-free"],
            imageURL: nil
        ),
        Recipe(
            id: "3",
            title: "Stir-Fry Recipe 3",
            description: "Quick recipe",
            servings: 2,
            ingredients: ["broccoli", "soy sauce", "ginger"],
            instructions: ["Step 1", "Step 2"],
            dietaryAttributes: ["vegan", "vegetarian", "plant-based", "dairy-free / lactose-free"],
            imageURL: nil
        ),
        Recipe(
            id: "4",
            title: "Salad Recipe 4",
            description: "Fresh recipe",
            servings: 2,
            ingredients: ["lettuce", "tomato", "cucumber"],
            instructions: ["Step 1"],
            dietaryAttributes: ["vegan", "vegetarian", "gluten-free", "dairy-free / lactose-free", "low-carb"],
            imageURL: nil
        ),
        Recipe(
            id: "5",
            title: "Burger Recipe 5",
            description: "Hearty recipe",
            servings: 4,
            ingredients: ["black beans", "breadcrumbs", "onion"],
            instructions: ["Step 1", "Step 2", "Step 3"],
            dietaryAttributes: ["vegan", "plant-based"],
            imageURL: nil
        ),
        Recipe(
            id: "6",
            title: "Salmon Recipe 6",
            description: "Light recipe",
            servings: 2,
            ingredients: ["salmon", "butter", "lemon"],
            instructions: ["Step 1", "Step 2"],
            dietaryAttributes: ["gluten-free", "low-carb", "nut-free"],
            imageURL: nil
        ),
        Recipe(
            id: "7",
            title: "Hummus Recipe 7",
            description: "Smooth dip",
            servings: 6,
            ingredients: ["chickpeas", "tahini", "lemon"],
            instructions: ["Step 1"],
            dietaryAttributes: ["vegan", "vegetarian", "plant-based", "gluten-free", "dairy-free / lactose-free"],
            imageURL: nil
        ),
        Recipe(
            id: "8",
            title: "Pasta Recipe 8",
            description: "Classic pasta",
            servings: 4,
            ingredients: ["spaghetti", "pancetta", "eggs"],
            instructions: ["Step 1", "Step 2"],
            dietaryAttributes: ["nut-free"],
            imageURL: nil
        )
    ]
}

// MARK: - StubNetworkService

private struct StubNetworkService: NetworkServiceProtocol {
    let recipes: [Recipe]

    func fetch<T: Decodable & Sendable>(endpoint: APIEndpoint) async throws -> T {
        guard let result = recipes as? T else {
            throw NetworkError.resourceNotFound("stub")
        }
        return result
    }
}

// MARK: - Suite: Recipe Service

@Suite("Recipe Service")
struct RecipeServiceTests {

    // MARK: Fetch

    @Suite("Fetch Recipes")
    struct FetchTests {

        @Test("Returns correct slice and metadata for page 1")
        func returnsFirstPage() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            let response = try await sut.fetchRecipes(page: 1, pageSize: 5)

            #expect(response.page == 1)
            #expect(response.data.count == 5)
            #expect(response.hasNextPage)
        }

        @Test(
            "hasNextPage reflects remaining pages",
            arguments: zip([1, 2], [true, false])
        )
        func pagination(page: Int, expectedHasNextPage: Bool) async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            let response = try await sut.fetchRecipes(page: page, pageSize: 5)

            #expect(response.hasNextPage == expectedHasNextPage)
        }

        @Test("Empty data source returns empty page with no next page")
        func emptyDataset() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: []))
            let response = try await sut.fetchRecipes(page: 1, pageSize: 10)

            #expect(response.data.isEmpty)
            #expect(!response.hasNextPage)
        }
    }

    // MARK: Dietary Attribute Filter

    @Suite("Search – Dietary Attribute Filter")
    struct DietaryFilterTests {

        @Test("Single attribute filter returns only recipes that carry that attribute")
        func singleAttribute() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.dietaryAttributes = ["vegan"]

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(!response.data.isEmpty)
            #expect(response.data.allSatisfy { $0.dietaryAttributes.contains("vegan") })
        }

        @Test("Multiple attributes filter uses AND logic — every selected attribute must be present")
        func multipleAttributesAND() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.dietaryAttributes = ["vegan", "gluten-free"]

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.allSatisfy {
                $0.dietaryAttributes.contains("vegan") && $0.dietaryAttributes.contains("gluten-free")
            })
        }

        @Test("Empty dietary filter returns all recipes without restriction")
        func emptyFilterReturnsAll() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            let filter = RecipeFilter()

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.count == Fixtures.sampleRecipes.count)
        }

        @Test("Filter for an attribute present in no recipe returns empty result")
        func noMatchingAttributeReturnsEmpty() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.dietaryAttributes = ["kosher"]

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.isEmpty)
        }

        @Test(
            "Attribute filter is case-insensitive",
            arguments: ["Vegan", "VEGAN", "vEgAn"]
        )
        func caseInsensitiveMatching(_ rawValue: String) async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.dietaryAttributes = [rawValue]

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(!response.data.isEmpty)
        }
    }

    // MARK: Servings Filter

    @Suite("Search – Servings Filter")
    struct ServingsFilterTests {

        @Test("Returns only recipes with the exact servings count requested")
        func exactServingsMatch() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.servings = 2

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.allSatisfy { $0.servings == 2 })
        }

        @Test("Nil servings filter returns all recipes without restricting count")
        func nilServingsReturnsAll() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            let filter = RecipeFilter()

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.count == Fixtures.sampleRecipes.count)
        }
    }

    // MARK: Text Query

    @Suite("Search – Text Query")
    struct TextQueryTests {

        @Test("Recipes with query in title, description, or instructions are returned")
        func matchesRecipeContent() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.searchQuery = "pizza"

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.allSatisfy {
                $0.title.localizedCaseInsensitiveContains("pizza")
                    || $0.description.localizedCaseInsensitiveContains("pizza")
                    || $0.instructions.contains { $0.localizedCaseInsensitiveContains("pizza") }
            })
        }

        @Test("Query with no matching recipes returns an empty result set")
        func noMatchReturnsEmpty() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.searchQuery = "xyznonexistent"

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.isEmpty)
        }
    }

    // MARK: Ingredient Filters

    @Suite("Search – Ingredient Filters")
    struct IngredientFilterTests {

        @Test("Include filter: every result contains all required ingredients")
        func includeIngredients() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.includeIngredients = ["flour"]

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.allSatisfy { recipe in
                recipe.ingredients.contains { $0.localizedCaseInsensitiveContains("flour") }
            })
        }

        @Test("Exclude filter: no result contains the excluded ingredient")
        func excludeIngredients() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.excludeIngredients = ["chicken"]

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(!response.data.contains { recipe in
                recipe.ingredients.contains { $0.localizedCaseInsensitiveContains("chicken") }
            })
        }

        @Test("Multiple include terms all must be present in each result")
        func multipleIncludeTerms() async throws {
            let sut = RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.includeIngredients = ["tomato", "lettuce"]

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.allSatisfy { recipe in
                recipe.ingredients.contains { $0.localizedCaseInsensitiveContains("tomato") }
                    && recipe.ingredients.contains { $0.localizedCaseInsensitiveContains("lettuce") }
            })
        }
    }
}

// MARK: - Suite: Recipe Filter

@Suite("Recipe Filter")
struct RecipeFilterTests {

    @Test("Default filter with no criteria set is not active")
    func defaultIsNotActive() {
        #expect(!RecipeFilter().isActive)
    }

    @Test(
        "Filter becomes active when any single criterion is set",
        arguments: ["searchQuery", "dietaryAttributes", "servings", "includeIngredients", "excludeIngredients"]
    )
    func isActive(criterion: String) {
        var filter = RecipeFilter()
        switch criterion {
        case "searchQuery":         filter.searchQuery = "pasta"
        case "dietaryAttributes":   filter.dietaryAttributes = ["vegan"]
        case "servings":            filter.servings = 2
        case "includeIngredients":  filter.includeIngredients = ["tomato"]
        default:                    filter.excludeIngredients = ["garlic"]
        }
        #expect(filter.isActive)
    }

    @Test("Resetting all criteria makes the filter inactive again")
    func resetBecomesInactive() {
        var filter = RecipeFilter()
        filter.searchQuery = "pasta"
        filter.dietaryAttributes = ["vegan"]

        filter = RecipeFilter()

        #expect(!filter.isActive)
    }

    @Test("Adding multiple dietary attributes are all reflected in isActive")
    func multipleDietaryAttributesActive() {
        var filter = RecipeFilter()
        filter.dietaryAttributes = ["vegan", "gluten-free", "halal"]
        #expect(filter.isActive)
        #expect(filter.dietaryAttributes.count == 3)
    }
}

// MARK: - Suite: Dietary Attribute

@Suite("Dietary Attribute")
struct DietaryAttributeTests {

    @Test("All cases have a non-empty displayName")
    func allCasesHaveDisplayName() {
        #expect(DietaryAttribute.allCases.allSatisfy { !$0.displayName.isEmpty })
    }

    @Test("All cases have a non-empty systemImage")
    func allCasesHaveSystemImage() {
        #expect(DietaryAttribute.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }

    @Test("rawValue matches the expected lowercase JSON string")
    func vegetarianRawValue() {
        #expect(DietaryAttribute.vegetarian.rawValue == "vegetarian")
        #expect(DietaryAttribute.dairyFree.rawValue == "dairy-free / lactose-free")
        #expect(DietaryAttribute.glutenFree.rawValue == "gluten-free")
    }

    @Test("String extension resolves known rawValues to the correct case")
    func stringExtensionResolvesKnownValues() {
        #expect("vegetarian".asDietaryAttribute == .vegetarian)
        #expect("gluten-free".asDietaryAttribute == .glutenFree)
        #expect("vegan".asDietaryAttribute == .vegan)
    }

    @Test("String extension returns nil for unknown values")
    func stringExtensionReturnsNilForUnknown() {
        #expect("unknown-attribute".asDietaryAttribute == nil)
        #expect("".asDietaryAttribute == nil)
    }

    @Test(
        "Well-known attributes resolve correctly from raw string",
        arguments: DietaryAttribute.allCases
    )
    func roundTripsFromRawValue(_ attribute: DietaryAttribute) {
        let resolved = attribute.rawValue.asDietaryAttribute
        #expect(resolved == attribute)
    }
}

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

// MARK: - Suite: Recipe Persistence

/// Each `@Test` receives a fresh struct instance, so `init()` runs before
/// every test — each gets its own isolated in-memory CoreData stack.
@Suite("Recipe Persistence")
struct RecipePersistenceTests {

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
}
