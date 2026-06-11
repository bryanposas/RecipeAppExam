// Persistence/FavoriteEntity.swift

import CoreData

// MARK: - FavoriteEntity

/// Lightweight record that marks a recipe as favorited.
///
/// Design notes:
///   - `recipeID` is the source of truth. It survives cache clears because the
///     delete rule on the `recipe` relationship is `.nullify` — when `RecipeEntity`
///     is removed, this record stays and `recipe` becomes nil.
///   - When recipes are re-fetched and saved, `RecipePersistenceService` re-links
///     any orphaned `FavoriteEntity` back to its `RecipeEntity`, restoring the
///     live join so the Favorites tab can display full recipe data again.
@objc(FavoriteEntity)
final class FavoriteEntity: NSManagedObject {

    @NSManaged var id: UUID
    @NSManaged var recipeID: String
    @NSManaged var favoritedAt: Date
    @NSManaged var recipe: RecipeEntity?

    static func fetchRequest() -> NSFetchRequest<FavoriteEntity> {
        NSFetchRequest<FavoriteEntity>(entityName: "FavoriteEntity")
    }
}
