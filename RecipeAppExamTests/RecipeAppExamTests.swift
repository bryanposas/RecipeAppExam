// RecipeAppExamTests.swift

import Foundation
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

// MARK: - Extended fixtures

private extension Fixtures {
    /// 20 recipes used for pagination tests (needs more than the default pageSize of 10).
    static let twentyRecipes: [Recipe] = (1...20).map { i in
        Recipe(
            id: "\(100 + i)",
            title: "Paged Recipe \(i)",
            description: "Description \(i)",
            servings: (i % 4) + 1,
            ingredients: ["ingredient \(i) a", "ingredient \(i) b", "tomato"],
            instructions: ["Step 1", "Step 2"],
            dietaryAttributes: i.isMultiple(of: 2) ? ["vegan", "gluten-free"] : ["halal"],
            imageURL: nil
        )
    }
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

// MARK: - FailingNetworkService

private struct FailingNetworkService: NetworkServiceProtocol {
    func fetch<T: Decodable & Sendable>(endpoint: APIEndpoint) async throws -> T {
        throw NetworkError.networkUnavailable
    }
}

// MARK: - StubPersistenceService

private final class StubPersistenceService: RecipePersistenceServiceProtocol, @unchecked Sendable {
    private var stored: [Recipe] = []

    func save(_ recipes: [Recipe]) async throws { stored = recipes }
    func fetchAll() async throws -> [Recipe] { stored }
    func deleteAll() async throws { stored = [] }
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

    // MARK: activeFilterCount

    @Test("Default filter has activeFilterCount of zero")
    func activeFilterCountDefaultIsZero() {
        #expect(RecipeFilter().activeFilterCount == 0)
    }

    @Test("Search query alone does not increment activeFilterCount")
    func searchQueryDoesNotIncrementActiveFilterCount() {
        var filter = RecipeFilter()
        filter.searchQuery = "pasta"
        #expect(filter.activeFilterCount == 0)
    }

    @Test("Each dietary attribute increments activeFilterCount by one")
    func dietaryAttributeIncrementsCount() {
        var filter = RecipeFilter()
        filter.dietaryAttributes = ["vegan", "halal"]
        #expect(filter.activeFilterCount == 2)
    }

    @Test("Servings filter increments activeFilterCount by one")
    func servingsIncrementsCount() {
        var filter = RecipeFilter()
        filter.servings = 4
        #expect(filter.activeFilterCount == 1)
    }

    @Test("Include and exclude ingredients both contribute to activeFilterCount")
    func ingredientsIncrementCount() {
        var filter = RecipeFilter()
        filter.includeIngredients = ["garlic", "onion"]
        filter.excludeIngredients = ["nuts"]
        #expect(filter.activeFilterCount == 3)
    }

    @Test("activeFilterCount sums all filter-sheet criteria correctly")
    func activeFilterCountSumsAllCriteria() {
        var filter = RecipeFilter()
        filter.searchQuery = "pasta"          // not counted
        filter.dietaryAttributes = ["vegan"]  // +1
        filter.servings = 2                   // +1
        filter.includeIngredients = ["flour"] // +1
        filter.excludeIngredients = ["nuts"]  // +1
        #expect(filter.activeFilterCount == 4)
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

// MARK: - Suite: Recipe Model

@Suite("Recipe Model")
struct RecipeModelTests {

    @Test("All fields are accessible after init")
    func allFieldsStoredOnInit() {
        let recipe = Recipe(
            id: "42",
            title: "Test Recipe",
            description: "A test description",
            servings: 3,
            ingredients: ["flour", "sugar"],
            instructions: ["mix", "bake"],
            dietaryAttributes: ["vegan", "gluten-free"],
            imageURL: "https://example.com/img.jpg"
        )
        #expect(recipe.id == "42")
        #expect(recipe.title == "Test Recipe")
        #expect(recipe.description == "A test description")
        #expect(recipe.servings == 3)
        #expect(recipe.ingredients == ["flour", "sugar"])
        #expect(recipe.instructions == ["mix", "bake"])
        #expect(recipe.dietaryAttributes == ["vegan", "gluten-free"])
        #expect(recipe.imageURL == "https://example.com/img.jpg")
    }

    @Test("Decodes from JSON using snake_case coding keys")
    func decodesFromJSON() throws {
        let json = """
        {
            "id": "7",
            "title": "JSON Recipe",
            "description": "Decoded from JSON",
            "servings": 4,
            "ingredients": ["eggs", "butter"],
            "instructions": ["crack eggs", "melt butter"],
            "dietary_attributes": ["vegetarian"],
            "image_url": "https://picsum.photos/seed/test/800/600"
        }
        """.data(using: .utf8)!

        let recipe = try JSONDecoder().decode(Recipe.self, from: json)

        #expect(recipe.id == "7")
        #expect(recipe.title == "JSON Recipe")
        #expect(recipe.dietaryAttributes == ["vegetarian"])
        #expect(recipe.imageURL == "https://picsum.photos/seed/test/800/600")
    }

    @Test("imageURL decodes as nil when image_url key is absent from JSON")
    func nilImageURLWhenKeyAbsent() throws {
        let json = """
        {
            "id": "8",
            "title": "No Image",
            "description": "No image URL",
            "servings": 2,
            "ingredients": [],
            "instructions": [],
            "dietary_attributes": []
        }
        """.data(using: .utf8)!

        let recipe = try JSONDecoder().decode(Recipe.self, from: json)
        #expect(recipe.imageURL == nil)
    }

    @Test("Encodes to JSON with snake_case keys matching CodingKeys")
    func encodesWithSnakeCaseKeys() throws {
        let recipe = Fixtures.sampleRecipes[0]
        let data = try JSONEncoder().encode(recipe)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["id"] != nil)
        #expect(json["title"] != nil)
        #expect(json["dietary_attributes"] != nil)
    }

    @Test("Hashable: two instances with identical data are equal and share the same hash")
    func hashableEqualityForIdenticalInstances() {
        let r1 = Fixtures.sampleRecipes[0]
        let r2 = Fixtures.sampleRecipes[0]
        #expect(r1 == r2)
        #expect(r1.hashValue == r2.hashValue)
    }

    @Test("Hashable: instances with different ids are not equal")
    func hashableInequalityForDifferentInstances() {
        let r1 = Fixtures.sampleRecipes[0]
        let r2 = Fixtures.sampleRecipes[1]
        #expect(r1 != r2)
    }

    @Test("Identifiable: id property matches the value passed at init")
    func identifiableIDMatchesInit() {
        let recipe = Fixtures.sampleRecipes[2]
        #expect(recipe.id == "3")
    }

    @Test("Recipe round-trips through encode then decode preserving all fields")
    func encodeThenDecodeRoundTrip() throws {
        let original = Fixtures.sampleRecipes[3]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Recipe.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.servings == original.servings)
        #expect(decoded.dietaryAttributes.sorted() == original.dietaryAttributes.sorted())
        #expect(decoded.imageURL == original.imageURL)
    }
}

// MARK: - Suite: Network Error

@Suite("Network Error")
struct NetworkErrorTests {

    @Test("resourceNotFound errorDescription contains the resource name")
    func resourceNotFoundDescription() {
        let error = NetworkError.resourceNotFound("recipes")
        #expect(error.errorDescription?.contains("recipes") == true)
    }

    @Test("decodingFailed errorDescription is non-nil")
    func decodingFailedDescription() {
        let inner = NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "bad json"])
        let error = NetworkError.decodingFailed(inner)
        #expect(error.errorDescription != nil)
    }

    @Test("networkUnavailable errorDescription is non-nil")
    func networkUnavailableDescription() {
        #expect(NetworkError.networkUnavailable.errorDescription != nil)
    }

    @Test("unknown errorDescription forwards the underlying error message")
    func unknownDescription() {
        let inner = NSError(domain: "test", code: 99, userInfo: [NSLocalizedDescriptionKey: "connection reset"])
        let error = NetworkError.unknown(inner)
        #expect(error.errorDescription?.contains("connection reset") == true)
    }

    @Test("Every NetworkError case produces a non-nil errorDescription")
    func allCasesHaveNonNilDescription() {
        let errors: [NetworkError] = [
            .resourceNotFound("x"),
            .decodingFailed(NSError(domain: "x", code: 0)),
            .networkUnavailable,
            .unknown(NSError(domain: "x", code: 0))
        ]
        #expect(errors.allSatisfy { $0.errorDescription != nil })
    }
}

// MARK: - Suite: API Endpoint

@Suite("API Endpoint")
struct APIEndpointTests {

    @Test("recipes endpoint maps to the 'recipes' JSON resource")
    func recipesResourceName() {
        #expect(APIEndpoint.recipes.resourceName == "recipes")
    }

    @Test("searchRecipes endpoint maps to the same 'recipes' JSON resource")
    func searchRecipesResourceName() {
        #expect(APIEndpoint.searchRecipes.resourceName == "recipes")
    }
}

// MARK: - Suite: Ingredient Name Extraction

@Suite("Ingredient Name Extraction")
struct IngredientExtractionTests {

    @Test(
        "Strips leading quantity and unit, returning just the ingredient name",
        arguments: [
            ("2 cups flour",              "Flour"),
            ("1 tsp salt",                "Salt"),
            ("3 tbsp olive oil",          "Olive Oil"),
            ("1/2 tsp baking powder",     "Baking Powder"),
            ("1 lb ground beef",          "Ground Beef"),
        ]
    )
    func stripsQuantityAndUnit(raw: String, expected: String) {
        #expect(RecipeService.extractIngredientName(from: raw) == expected)
    }

    @Test("Strips text after the first comma (prep notes)")
    func stripsAfterComma() {
        let result = RecipeService.extractIngredientName(from: "3 large onions, finely diced")
        #expect(result == "Onions")
    }

    @Test("Removes parenthetical weight/size notes")
    func removesParentheticals() {
        let result = RecipeService.extractIngredientName(from: "(14 oz) canned tomatoes")
        #expect(result.localizedCaseInsensitiveContains("tomato"))
    }

    @Test("Plain ingredient names are returned capitalised and unchanged otherwise")
    func preservesPlainName() {
        #expect(RecipeService.extractIngredientName(from: "garlic") == "Garlic")
        #expect(RecipeService.extractIngredientName(from: "basil") == "Basil")
    }

    @Test("Strips leading size adjectives before the ingredient name")
    func stripsLeadingAdjectives() {
        let result = RecipeService.extractIngredientName(from: "fresh basil leaves")
        #expect(result == "Basil Leaves")
    }

    @Test("allIngredientNames deduplicates the same ingredient appearing in multiple recipes")
    func allIngredientNamesDeduplicates() {
        let r1 = Recipe(id: "1", title: "A", description: "", servings: 1,
                        ingredients: ["tomato", "garlic"], instructions: [],
                        dietaryAttributes: [], imageURL: nil)
        let r2 = Recipe(id: "2", title: "B", description: "", servings: 1,
                        ingredients: ["tomato", "onion"], instructions: [],
                        dietaryAttributes: [], imageURL: nil)

        let names = RecipeService.allIngredientNames(from: [r1, r2])
        let tomatoCount = names.filter { $0.lowercased() == "tomato" }.count
        #expect(tomatoCount == 1)
    }

    @Test("allIngredientNames returns names sorted alphabetically")
    func allIngredientNamesSorted() {
        let names = RecipeService.allIngredientNames(from: Fixtures.sampleRecipes)
        #expect(names == names.sorted())
    }

    @Test("allIngredientNames filters out strings shorter than 3 characters")
    func allIngredientNamesFiltersShortStrings() {
        let recipe = Recipe(id: "x", title: "Short", description: "", servings: 1,
                            ingredients: ["a", "bb", "ccc", "dddd"], instructions: [],
                            dietaryAttributes: [], imageURL: nil)
        let names = RecipeService.allIngredientNames(from: [recipe])
        #expect(!names.contains("A"))
        #expect(!names.contains("Bb"))
        #expect(names.contains("Ccc"))
        #expect(names.contains("Dddd"))
    }

    @Test("allIngredientNames returns empty array for an empty recipe collection")
    func allIngredientNamesEmptyInput() {
        #expect(RecipeService.allIngredientNames(from: []).isEmpty)
    }
}

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

// MARK: - Suite: Recipe List ViewModel

@Suite("Recipe List ViewModel")
struct RecipeListViewModelTests {

    // MARK: - Initial state

    @Test("Initial state: recipes are empty, isLoading is false, no error, no next page")
    @MainActor
    func initialState() {
        let sut = RecipeListViewModel(
            recipeService: RecipeService(networkService: StubNetworkService(recipes: [])),
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
            recipeService: RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes)),
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
            recipeService: RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes)),
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
            recipeService: RecipeService(networkService: StubNetworkService(recipes: Fixtures.twentyRecipes)),
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
            recipeService: RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes)),
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
            recipeService: RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes)),
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
            recipeService: RecipeService(networkService: StubNetworkService(recipes: Fixtures.twentyRecipes)),
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
            recipeService: RecipeService(networkService: StubNetworkService(recipes: Fixtures.twentyRecipes)),
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
            recipeService: RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes)),
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
            recipeService: RecipeService(networkService: StubNetworkService(recipes: Fixtures.sampleRecipes)),
            persistenceService: StubPersistenceService()
        )
        await sut.loadRecipes()
        let unfilteredCount = sut.recipes.count

        sut.filter.dietaryAttributes = ["vegan"]
        await sut.loadRecipes()

        #expect(sut.recipes.count < unfilteredCount)
        #expect(sut.recipes.allSatisfy { $0.dietaryAttributes.contains("vegan") })
    }
}
