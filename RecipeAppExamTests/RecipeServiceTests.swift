// RecipeServiceTests.swift

import Foundation
import Testing
@testable import RecipeAppExam

// MARK: - Suite: Recipe Service

@Suite("Recipe Service")
struct RecipeServiceTests {

    // MARK: Fetch

    @Suite("Fetch Recipes")
    struct FetchTests {

        @Test("Returns correct slice and metadata for page 1")
        func returnsFirstPage() async throws {
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
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
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
            let response = try await sut.fetchRecipes(page: page, pageSize: 5)

            #expect(response.hasNextPage == expectedHasNextPage)
        }

        @Test("Empty data source returns empty page with no next page")
        func emptyDataset() async throws {
            let sut = RecipeService(networkService: MockNetworkService(recipes: []))
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
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.dietaryAttributes = ["vegan"]

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(!response.data.isEmpty)
            #expect(response.data.allSatisfy { $0.dietaryAttributes.contains("vegan") })
        }

        @Test("Multiple attributes filter uses AND logic — every selected attribute must be present")
        func multipleAttributesAND() async throws {
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.dietaryAttributes = ["vegan", "gluten-free"]

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.allSatisfy {
                $0.dietaryAttributes.contains("vegan") && $0.dietaryAttributes.contains("gluten-free")
            })
        }

        @Test("Empty dietary filter returns all recipes without restriction")
        func emptyFilterReturnsAll() async throws {
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
            let filter = RecipeFilter()

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.count == Fixtures.sampleRecipes.count)
        }

        @Test("Filter for an attribute present in no recipe returns empty result")
        func noMatchingAttributeReturnsEmpty() async throws {
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
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
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
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
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.servings = 2

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.allSatisfy { $0.servings == 2 })
        }

        @Test("Nil servings filter returns all recipes without restricting count")
        func nilServingsReturnsAll() async throws {
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
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
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
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
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
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
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.includeIngredients = ["flour"]

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(response.data.allSatisfy { recipe in
                recipe.ingredients.contains { $0.localizedCaseInsensitiveContains("flour") }
            })
        }

        @Test("Exclude filter: no result contains the excluded ingredient")
        func excludeIngredients() async throws {
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
            var filter = RecipeFilter()
            filter.excludeIngredients = ["chicken"]

            let response = try await sut.searchRecipes(filter: filter, page: 1, pageSize: 50)

            #expect(!response.data.contains { recipe in
                recipe.ingredients.contains { $0.localizedCaseInsensitiveContains("chicken") }
            })
        }

        @Test("Multiple include terms all must be present in each result")
        func multipleIncludeTerms() async throws {
            let sut = RecipeService(networkService: MockNetworkService(recipes: Fixtures.sampleRecipes))
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
