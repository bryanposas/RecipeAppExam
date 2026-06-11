// RecipeTests.swift

import Foundation
import Testing
@testable import RecipeAppExam

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
