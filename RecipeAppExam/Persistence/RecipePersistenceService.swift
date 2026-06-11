// Persistence/RecipePersistenceService.swift

import CoreData

// MARK: - RecipePersistenceServiceProtocol

protocol RecipePersistenceServiceProtocol: Sendable {
    func save(_ recipes: [Recipe]) async throws
    func fetchAll() async throws -> [Recipe]
    func deleteAll() async throws
}

// MARK: - RecipePersistenceService

/// Handles all CoreData read/write operations for recipes.
///
/// Concurrency rules enforced here:
///   - Writes run on a private background context (`newBackgroundContext`)
///     so the main thread is never blocked.
///   - `context.perform { }` guarantees each operation executes on the
///     context's own serial queue, preventing data races.
///   - `NSBatchDeleteRequest` is used for bulk deletes to skip individual
///     object loading overhead.
final class RecipePersistenceService: RecipePersistenceServiceProtocol {

    private let coreDataStack: CoreDataStack

    // MARK: - Init

    init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
    }

    // MARK: - RecipePersistenceServiceProtocol

    /// Upserts recipes by `id` on a background context.
    func save(_ recipes: [Recipe]) async throws {
        let context = coreDataStack.newBackgroundContext()
        try await context.perform {
            for recipe in recipes {
                let fetchRequest = NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
                fetchRequest.predicate = NSPredicate(format: "id == %@", recipe.id)

                let existing = try context.fetch(fetchRequest).first
                let entity = existing ?? RecipeEntity(context: context)
                entity.update(from: recipe)
            }
            guard context.hasChanges else { return }
            try context.save()
        }
    }

    /// Fetches all cached recipes sorted by title using the view context.
    func fetchAll() async throws -> [Recipe] {
        let context = coreDataStack.viewContext
        return try await context.perform {
            let fetchRequest = NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
            return try context.fetch(fetchRequest).compactMap { $0.toRecipe() }
        }
    }

    /// Removes every recipe from the store.
    /// Uses individual object deletions rather than NSBatchDeleteRequest so it works
    /// correctly with both SQLite and in-memory stores (batch requests are unsupported
    /// on in-memory stores and behave inconsistently across OS versions).
    func deleteAll() async throws {
        let context = coreDataStack.newBackgroundContext()
        try await context.perform {
            let fetchRequest = NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
            let objects = try context.fetch(fetchRequest)
            for object in objects {
                context.delete(object)
            }
            if context.hasChanges {
                try context.save()
            }

            // Propagate deletions to the view context so the UI refreshes.
            let deletedIDs = objects.map(\.objectID)
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: deletedIDs],
                into: [self.coreDataStack.viewContext]
            )
        }
    }
}
