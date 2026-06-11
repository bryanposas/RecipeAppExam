// Persistence/RecipeEntity.swift

import CoreData

// MARK: - RecipeEntity

/// NSManagedObject subclass that maps to the "RecipeEntity" CoreData entity.
/// Keeps CoreData concerns isolated — callers work with `Recipe` value types
/// and only touch this class through RecipePersistenceService.
@objc(RecipeEntity)
final class RecipeEntity: NSManagedObject {

    @NSManaged var id: String
    @NSManaged var title: String
    @NSManaged var recipeDescription: String
    @NSManaged var servings: Int16
    @NSManaged var ingredientsData: Data?
    @NSManaged var instructionsData: Data?
    @NSManaged var dietaryAttributesData: Data?
    @NSManaged var imageURL: String?
    @NSManaged var cachedAt: Date
}

// MARK: - Domain mapping

extension RecipeEntity {

    /// Converts the managed object back to a plain `Recipe` value type.
    func toRecipe() -> Recipe? {
        let ingredients: [String]   = decode(ingredientsData) ?? []
        let instructions: [String]  = decode(instructionsData) ?? []
        let dietaryAttributes: [String] = decode(dietaryAttributesData) ?? []

        return Recipe(
            id: id,
            title: title,
            description: recipeDescription,
            servings: Int(servings),
            ingredients: ingredients,
            instructions: instructions,
            dietaryAttributes: dietaryAttributes,
            imageURL: imageURL
        )
    }

    /// Writes all fields from a `Recipe` value type into this managed object.
    func update(from recipe: Recipe, cachedAt date: Date = Date()) {
        id = recipe.id
        title = recipe.title
        recipeDescription = recipe.description
        servings = Int16(recipe.servings)
        imageURL = recipe.imageURL
        cachedAt = date
        ingredientsData = encode(recipe.ingredients)
        instructionsData = encode(recipe.instructions)
        dietaryAttributesData = encode(recipe.dietaryAttributes)
    }

    // MARK: - Helpers

    private func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private func decode<T: Decodable>(_ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
