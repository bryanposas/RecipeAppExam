// Services/FavoritesService.swift

import Combine
import CoreData
import Foundation

// MARK: - FavoritesServiceProtocol

/// Defines the contract for favorites management.
/// Using a protocol instead of the concrete class lets every consumer
/// (ViewModel, previews, tests) depend on the interface, not the implementation.
/// The ViewModel owns this dependency explicitly — no ambient environment injection.
@MainActor
protocol FavoritesServiceProtocol: AnyObject {
    var favorites: [Recipe] { get }
    var favoriteIDs: Set<String> { get }
    /// Type-erased publisher that fires after every state change.
    /// Consumers subscribe to stay in sync without coupling to ObservableObject.
    var favoritesPublisher: AnyPublisher<[Recipe], Never> { get }
    var favoriteIDsPublisher: AnyPublisher<Set<String>, Never> { get }
    func toggle(_ recipe: Recipe) async
    func isFavorite(_ id: String) -> Bool
    func loadFavorites() async
}

// MARK: - FavoritesService

/// Manages the user's favorited recipes, backed by CoreData.
///
/// Architecture notes:
///   - `favoriteIDs` is the authoritative fast-lookup set — always current,
///     used by `isFavorite(_:)` for O(1) checks on every grid card.
///   - `favorites` holds the full `Recipe` value types for the Favorites tab.
///     It is populated from the `FavoriteEntity.recipe` relationship, which is
///     re-established by `RecipePersistenceService.save()` on each cache refresh.
///   - When the cache is cleared, `FavoriteEntity` records survive (nullify delete
///     rule), so `favoriteIDs` stays accurate and heart indicators remain correct.
///     `favorites` may temporarily be empty until the next cache refresh restores
///     the relationships — at which point the `NSManagedObjectContextDidSave`
///     observer triggers a reload automatically.
@MainActor
final class FavoritesService: ObservableObject, FavoritesServiceProtocol {

    static let shared = FavoritesService()

    @Published private(set) var favorites: [Recipe] = []
    @Published private(set) var favoriteIDs: Set<String> = []

    private let coreDataStack: CoreDataStack
    private var saveObserver: NSObjectProtocol?

    // MARK: - Init

    private init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
        Task { await loadFavorites() }
        observeCacheSaves()
    }

    // MARK: - Testing Factories

    static func makeForTesting() -> FavoritesService {
        FavoritesService(coreDataStack: CoreDataStack(inMemory: true))
    }

    static func makeForTesting(coreDataStack: CoreDataStack) -> FavoritesService {
        FavoritesService(coreDataStack: coreDataStack)
    }

    // MARK: - FavoritesServiceProtocol Publishers

    var favoritesPublisher: AnyPublisher<[Recipe], Never> {
        $favorites.eraseToAnyPublisher()
    }

    var favoriteIDsPublisher: AnyPublisher<Set<String>, Never> {
        $favoriteIDs.eraseToAnyPublisher()
    }

    // MARK: - Public API

    /// Adds or removes the recipe from favorites, persisting to CoreData.
    /// Also attempts to link the FavoriteEntity to the RecipeEntity cache record
    /// so the Favorites tab can display full data immediately.
    func toggle(_ recipe: Recipe) async {
        let context = coreDataStack.newBackgroundContext()
        let recipeID = recipe.id

        try? await context.perform {
            let request = FavoriteEntity.fetchRequest()
            request.predicate = NSPredicate(format: "recipeID == %@", recipeID)
            request.fetchLimit = 1

            if let existing = try context.fetch(request).first {
                context.delete(existing)
            } else {
                let entity = FavoriteEntity(context: context)
                entity.id = UUID()
                entity.recipeID = recipeID
                entity.favoritedAt = Date()

                // Link to RecipeEntity if currently in cache — non-critical if absent
                let recipeRequest = NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
                recipeRequest.predicate = NSPredicate(format: "id == %@", recipeID)
                recipeRequest.fetchLimit = 1
                entity.recipe = try? context.fetch(recipeRequest).first
            }

            if context.hasChanges { try context.save() }
        }

        await loadFavorites()
    }

    /// O(1) check whether a recipe ID is currently favorited.
    func isFavorite(_ id: String) -> Bool {
        favoriteIDs.contains(id)
    }

    // MARK: - Internal (exposed for test synchronization)

    /// Reloads `favorites` and `favoriteIDs` from the persistent store.
    /// Called automatically after `toggle` and whenever the recipe cache is refreshed.
    func loadFavorites() async {
        let context = coreDataStack.newBackgroundContext()
        let (ids, recipes): (Set<String>, [Recipe]) = await context.perform {
            let request = FavoriteEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "favoritedAt", ascending: false)]
            let entities = (try? context.fetch(request)) ?? []
            let ids = Set(entities.compactMap { $0.recipeID })
            let recipes = entities.compactMap { $0.recipe?.toRecipe() }
            return (ids, recipes)
        }
        favoriteIDs = ids
        favorites = recipes
    }

    // MARK: - Private

    /// Listens for CoreData saves that insert or update RecipeEntity records.
    /// When the recipe cache is refreshed, `RecipePersistenceService` re-links
    /// any orphaned FavoriteEntity rows — this observer picks that up and refreshes
    /// the published `favorites` array so the UI reflects the restored relationships.
    private func observeCacheSaves() {
        saveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
            let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
            let hasRecipeChanges = inserted.union(updated).contains { $0 is RecipeEntity }
            guard hasRecipeChanges else { return }
            Task { @MainActor [weak self] in await self?.loadFavorites() }
        }
    }
}
