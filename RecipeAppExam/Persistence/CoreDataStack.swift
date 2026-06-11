// Persistence/CoreDataStack.swift

import CoreData

// MARK: - CoreDataStack

final class CoreDataStack: @unchecked Sendable {

    // MARK: - Model Version
    //
    // Bump this constant every time the schema changes or a data migration is needed.
    // Then add a corresponding entry to `migrationSteps` below.
    //
    // History:
    //   v1 — initial schema (isVegetarian Bool attribute)
    //   v2 — replaced isVegetarian with dietaryAttributesData ([String] stored as Data)
    static let currentModelVersion: Int = 2

    private static let modelVersionKey = "com.recipeapp.coredata.modelVersion"

    // MARK: - Migration Step

    struct MigrationStep {
        /// Describes what changed — appears in logs and serves as documentation.
        let description: String
        /// How to handle the transition.
        let policy: Policy

        enum Policy {
            /// Existing data is incompatible and safe to discard.
            /// The store will already be destroyed by CoreData's hash-mismatch check;
            /// declaring .wipe here documents the intent and stamps the version.
            case wipe
            /// Run a data transformation in place on a background context.
            /// The closure receives a background NSManagedObjectContext; save is
            /// handled automatically after the closure returns without throwing.
            case transform((NSManagedObjectContext) throws -> Void)
        }
    }

    // MARK: - Migration Registry
    //
    // Add one entry here each time you bump currentModelVersion.
    // Key = the version being migrated TO (always currentModelVersion after your bump).
    //
    // .wipe   — use when attributes were added, removed, or changed type.
    //           CoreData will reject the store; this documents why.
    // .transform — use when the schema is unchanged but stored values need updating
    //              (e.g. normalising capitalisation, backfilling a new optional field).
    private static let migrationSteps: [Int: MigrationStep] = [
        2: MigrationStep(
            description: "Replaced is_vegetarian (Bool) with dietary_attributes ([String] as binary Data)",
            policy: .wipe
        )
        // Example of a future transform migration:
        // 3: MigrationStep(
        //     description: "Normalise all title fields to title-case",
        //     policy: .transform { context in
        //         let request = NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
        //         for entity in try context.fetch(request) {
        //             entity.title = entity.title.capitalized
        //         }
        //     }
        // )
    ]

    // MARK: - Properties

    let persistentContainer: NSPersistentContainer

    var viewContext: NSManagedObjectContext { persistentContainer.viewContext }

    // MARK: - Singleton

    static let shared: CoreDataStack = CoreDataStack(inMemory: false)

    // MARK: - Init

    init(inMemory: Bool = false) {
        persistentContainer = NSPersistentContainer(
            name: "RecipeAppExam",
            managedObjectModel: CoreDataStack.managedObjectModel
        )

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            persistentContainer.persistentStoreDescriptions = [description]
        }

        var storeWasRebuilt = false

        persistentContainer.loadPersistentStores { storeDescription, error in
            if let error {
                // Schema mismatch: destroy the old store and create a fresh one.
                // This is safe because CoreData is used as a re-fetchable network cache.
                if !inMemory, let storeURL = storeDescription.url {
                    try? NSPersistentStoreCoordinator(managedObjectModel: CoreDataStack.managedObjectModel)
                        .destroyPersistentStore(at: storeURL, type: .sqlite)
                    self.persistentContainer.loadPersistentStores { _, retryError in
                        if let retryError {
                            fatalError("CoreData store failed after rebuild: \(retryError.localizedDescription)")
                        }
                    }
                    storeWasRebuilt = true
                } else {
                    fatalError("CoreData store failed to load: \(error.localizedDescription)")
                }
            }
        }

        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        if !inMemory {
            runPendingMigrations(storeWasRebuilt: storeWasRebuilt)
        }
    }

    // MARK: - Background Context

    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = persistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }

    // MARK: - Programmatic Model

    static let managedObjectModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let recipeEntity = NSEntityDescription()
        recipeEntity.name = "RecipeEntity"
        recipeEntity.managedObjectClassName = NSStringFromClass(RecipeEntity.self)
        recipeEntity.properties = [
            makeAttribute("id", type: .stringAttributeType),
            makeAttribute("title", type: .stringAttributeType),
            makeAttribute("recipeDescription", type: .stringAttributeType),
            makeAttribute("servings", type: .integer16AttributeType, defaultValue: 0),
            makeAttribute("ingredientsData", type: .binaryDataAttributeType, optional: true),
            makeAttribute("instructionsData", type: .binaryDataAttributeType, optional: true),
            makeAttribute("dietaryAttributesData", type: .binaryDataAttributeType, optional: true),
            makeAttribute("imageURL", type: .stringAttributeType, optional: true),
            makeAttribute("cachedAt", type: .dateAttributeType)
        ]

        model.entities = [recipeEntity]
        return model
    }()

    // MARK: - Private

    private static func makeAttribute(
        _ name: String,
        type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.isOptional = optional
        attr.defaultValue = defaultValue
        return attr
    }

    // MARK: - Migration Runner

    private func runPendingMigrations(storeWasRebuilt: Bool) {
        let stored = UserDefaults.standard.integer(forKey: Self.modelVersionKey)
        // integer(forKey:) returns 0 when the key is absent, meaning first launch
        // or first launch after this versioning system was introduced. Treat 0 as v1.
        let fromVersion = stored == 0 ? 1 : stored
        let toVersion = Self.currentModelVersion

        guard fromVersion < toVersion else {
            // Stamp on first launch so future runs have a baseline.
            if stored == 0 {
                UserDefaults.standard.set(toVersion, forKey: Self.modelVersionKey)
            }
            return
        }

        for version in (fromVersion + 1)...toVersion {
            guard let step = Self.migrationSteps[version] else {
                // No registered step for this version jump — skip.
                continue
            }

            switch step.policy {
            case .wipe:
                // Store was already destroyed by CoreData's hash-mismatch check.
                // Nothing to run; the version stamp below records that we handled it.
                break

            case .transform(let block):
                // Skip transform if the store was just wiped — there is no old data.
                guard !storeWasRebuilt else { break }

                let ctx = newBackgroundContext()
                do {
                    try ctx.performAndWait {
                        try block(ctx)
                        if ctx.hasChanges { try ctx.save() }
                    }
                } catch {
                    // Transforms are non-fatal for a network cache — log and continue.
                    print("[CoreDataStack] Migration to v\(version) '\(step.description)' failed: \(error)")
                }
            }
        }

        UserDefaults.standard.set(toVersion, forKey: Self.modelVersionKey)
    }
}
