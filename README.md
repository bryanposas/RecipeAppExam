# RecipeAppExam

A native iOS recipe browser built with **Swift + SwiftUI**, MVVM architecture, CoreData persistence, a mock network layer, and a TDD-first workflow. The project is intentionally structured for long-term maintainability and scalability.

---

## Setup & Running

### Requirements

- Xcode 16.0 or later
- iOS 17.5 simulator or device
- No third-party dependencies — zero SPM packages required

### Open in Xcode

```bash
open RecipeAppExam.xcodeproj
```

Select any iOS 17.5+ simulator and press **Cmd+R**.

### Run Tests Locally

```bash
xcodebuild test \
  -project RecipeAppExam.xcodeproj \
  -scheme RecipeAppExam \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -enableCodeCoverage YES
```

All 60+ unit tests pass with zero failures. The suite covers models, services, persistence, the view model, and the favorites system at 80%+ logic coverage.

---

## Continuous Integration

Every push to `main` and every pull request targeting `main` triggers a two-job pipeline defined in `.github/workflows/ci.yml`.

### Jobs

| Job | Runner | Purpose |
| --- | --- | --- |
| **SwiftLint** | `macos-15` | Enforces coding style. Outputs inline PR annotations so violations appear directly in the diff, not just in logs. |
| **Build & Test** | `macos-15` | Compiles the app, runs the full test suite with code coverage enabled, prints a per-file coverage table to the run summary, and uploads a downloadable `.xcresult` bundle as an artifact. |

The two jobs run **in parallel** — lint feedback arrives before the simulator build finishes, so reviewers get style feedback faster.

### Pipeline Design Decisions

**`concurrency` group with `cancel-in-progress: true`**
When a developer pushes a quick follow-up commit, the in-progress run for the previous commit is cancelled automatically. This prevents stale CI runs from occupying runner capacity and eliminates the confusing situation where an old failing run blocks a merge even after it has been fixed.

**`set -o pipefail` before `xcodebuild | xcbeautify`**
Without this flag, the shell pipe's exit code is determined by `xcbeautify` (the last command), not `xcodebuild`. A build failure would silently appear green. `pipefail` ensures the step fails when `xcodebuild` returns a non-zero exit code, regardless of what the pipe does with the output.

**DerivedData caching**
The cache key hashes all `.swift` source files and `project.pbxproj`. This means cache hits on unchanged runs cut build time significantly, while any source or project change correctly busts the cache for a clean rebuild.

**`CODE_SIGNING_ALLOWED=NO`**
Simulator builds in CI do not need a valid signing identity. Omitting this flag causes `xcodebuild` to search for certificates that don't exist on the runner and produces noisy warnings or failures unrelated to the actual code.

**Coverage via `.xcresult` artifact**
Rather than running a third-party coverage service, the full Xcode result bundle is uploaded as a 7-day artifact. Any team member can download it and open it in Xcode for per-line coverage inspection or test replay — no extra tooling required.

### Branch Protection Setup

> These steps are required **once**, after the first CI run has completed and GitHub has registered the check names.

1. Go to **Settings → Branches → Add branch protection rule** for `main`
2. Enable **Require status checks to pass before merging**
3. Search for and add `SwiftLint` and `Build & Test` as required checks
4. Save — pull requests cannot be merged until both jobs pass

### SwiftLint Configuration

Rules are defined in `.swiftlint.yml`. The app target is linted; test files are excluded because test-specific patterns (longer functions, explicit `nil` values) would generate noise without improving production code quality.

Key enforcements aligned with project conventions:

| Rule | Rationale |
| --- | --- |
| `empty_count` / `empty_string` | Enforces `.isEmpty` idioms over comparison operators |
| `first_where` | Prevents the `.filter { }.first` anti-pattern |
| `modifier_order` | Keeps `@MainActor`, `final`, `private` in a consistent order across the codebase |
| `redundant_nil_coalescing` | Catches `?? nil` which is always a logic mistake |
| `line_length` (130 warn / 160 error) | Long lines in regex patterns were refactored into named constants, improving readability as a side effect |
| `no_print_in_production` (custom) | Warns on any bare `print()` — production code should use a structured logger |

---

## Architecture Overview

```text
RecipeAppExam/
├── Models/               # Pure value types — Recipe, PaginatedResponse, RecipeFilter
├── ViewModels/           # RecipeListViewModel (@MainActor ObservableObject)
├── Views/                # SwiftUI views — one focused component per file
├── Services/             # NetworkServiceProtocol + NetworkService (bundle + live modes)
│                         # RecipeService (filter + paginate), FavoritesService
│                         # ConnectivityMonitor (NWPathMonitor)
├── Persistence/          # CoreDataStack, RecipeEntity, FavoriteEntity
│                         # RecipePersistenceService
├── Resources/            # recipes.json (20 mock recipes)
└── Extensions/           # Reserved for shared View helpers
```

### MVVM Data Flow

```text
NetworkService → RecipeService → RecipeListViewModel → RecipeListView
                                            ↕                      ↕
                               RecipePersistenceService      FavoritesService
                                      ↕                            ↕
                                 CoreDataStack              CoreDataStack
                               (RecipeEntity cache)       (FavoriteEntity store)
```

`RecipeListViewModel` is the single source of truth for the recipe list screen. `FavoritesService` is injected into the ViewModel as `any FavoritesServiceProtocol` — views never reference the service directly. `RecipeListViewModel` bridges the service's Combine publishers into its own `@Published` properties, so views observe a single `ObservableObject` with compile-checked dependencies instead of a hidden ambient singleton.

---

## Features

| Feature | Description |
| --- | --- |
| Recipe grid | 2-column `LazyVGrid` with paginated loading |
| Search | Debounced full-text search across title, description, and instructions |
| Filter | Dietary attributes, serving count, include/exclude ingredients (chip picker) |
| Favorites | Heart toggle on cards and detail view; persisted to CoreData |
| Offline banner | Dismissable connectivity error via `NWPathMonitor` |
| Offline cache | Last fetched recipes available without a network connection |
| Pagination | Page-sliced at service layer; "load more" triggers on scroll |

---

## Key Design Decisions

| Decision | Rationale |
| --- | --- |
| `NetworkService` dual-mode design (bundle + live) | Default `init()` loads from the bundled `recipes.json` with simulated latency. Pass `baseURL: URL` to switch to real `URLSession` requests — no other code changes needed anywhere in the stack |
| Filtering done in-memory inside `RecipeService` | Single source of truth for query logic; trivially unit-testable without a network |
| Pagination sliced at service layer | JSON stays a flat array; pagination behaviour is isolated and independently testable |
| CoreData model defined in Swift code (`CoreDataStack.managedObjectModel`) | Schema lives in source control as readable diffs — no binary `.xcdatamodeld` bundle |
| `@MainActor` on `RecipeListViewModel` | All `@Published` mutations are guaranteed on the main thread — no `DispatchQueue.main.async` scattered through views |
| `context.perform { }` for all CoreData operations | Uses the async Swift concurrency variant (iOS 15+); each context's serial queue prevents data races |
| `ConnectivityMonitor` via `NWPathMonitor` + Combine | Real-time path updates without polling; `assign(to:)` avoids retain cycles |
| Debounced `$filter` observation (350 ms) | Prevents a network fetch on every keystroke while the user is still typing |
| `FavoritesService` injected via `FavoritesServiceProtocol` | `RecipeListViewModel` holds `any FavoritesServiceProtocol` as an explicit constructor parameter. Views observe only the ViewModel — no ambient singletons, no runtime crashes if an `@EnvironmentObject` is missing, and the mock substitution in tests is a one-liner |
| `FavoriteEntity.recipeID` as source of truth | The favorite marker survives cache clears. The `recipe` relationship is a live join cache — re-established automatically by `RecipePersistenceService.save()` on the next fetch |

---

## Favorites Architecture: Design Evolution

This section documents the architectural journey of the Favorites feature. It went through three distinct proposals before arriving at the final design, and the decisive turning points came from questioning initial assumptions.

### Initial Implementation — UserDefaults JSON

The first implementation stored favorited `[Recipe]` objects as JSON in `UserDefaults`. This was fast to build and required no new persistence infrastructure.

**Why it was insufficient for scale:**

- It introduced a second persistence mechanism alongside CoreData for the same domain object
- `UserDefaults` has no query capabilities — the entire blob is loaded and decoded on every read
- There is no relationship between a favorited recipe and its cached `RecipeEntity`, so data can diverge silently

---

### > Architectural Challenge: Moving Favorites to CoreData

> *"Why not just save the favorites as an entity in CoreData and just make the favorite service pull those data from the database to the controllers when they need?"*

This is exactly the kind of question that separates engineers who think long-term from those who reach for the fastest solution. The project already had a CoreData persistence layer, a programmatic model, and concurrency-safe context management. Using `UserDefaults` for favorites was architecturally inconsistent — two separate persistence mechanisms for what is fundamentally the same domain.

The decision was made to model `FavoriteEntity` as a first-class CoreData entity with a proper relationship to `RecipeEntity`. The proposed relationship — one `RecipeEntity` → many `FavoriteEntity` records (one-to-many) — is intentionally forward-looking: it supports future features like multiple favorites lists, per-favorite notes, and multi-user records without requiring a schema migration.

---

### The "Protect From Deletion" Trap

When designing around cache clears (`deleteAll()`), three options were considered:

1. **Cascade** — deleting `RecipeEntity` also deletes `FavoriteEntity`. Favorites lost on cache refresh. Unacceptable.
2. **Nullify** — deleting `RecipeEntity` sets `FavoriteEntity.recipe = nil`. Favorite record survives; relationship is temporarily broken.
3. **Protect favorited recipes from `deleteAll()`** — skip deletion for any `RecipeEntity` that has a `favorites` relationship. Initially proposed as the simplest user-facing solution.

**Option 3 was proposed first.** It seemed pragmatic — favorites stay, the cache clear works for everything else.

---

### > Catching the Data Integrity Flaw

> *"What is the cons of the third option? Won't it make the favorited recipe become stale if they stay instead of being cleared?"*

This is a senior-level instinct: immediately asking "what breaks downstream?" rather than accepting a solution at face value. If a recipe's title, image, ingredients, or instructions change upstream and the cache is refreshed, the protected `RecipeEntity` is never overwritten. The user's favorites tab silently displays outdated data with no indication it is stale. The "protection" trades one problem for a worse one — corrupted data that the user cannot detect or recover from.

This observation directly led to discarding option 3 and arriving at the correct design.

---

### Final Design — Decoupled Identity

The solution separates *favorites identity* from *recipe cache data*:

- `FavoriteEntity` stores `recipeID (String)` and `favoritedAt (Date)`. These are the source of truth and survive indefinitely.
- The `recipe: RecipeEntity?` relationship uses `.nullifyDeleteRule`. When the cache is cleared, the relationship becomes `nil` — but the `FavoriteEntity` record stays.
- `RecipePersistenceService.save()` re-links any orphaned `FavoriteEntity` (where `recipe == nil`) to the freshly saved `RecipeEntity` in the same write operation. No extra round-trip.
- `FavoritesService` observes `NSManagedObjectContextDidSave` notifications. When it detects that `RecipeEntity` records were inserted or updated, it automatically reloads — so the Favorites tab refreshes itself the moment the cache is repopulated.

**Result:** `deleteAll()` is unconditional and clean. Recipes are always fresh. Favorites identity is never lost. The UI heals itself automatically after a cache refresh.

```text
Cache clear:
  RecipeEntity deleted → FavoriteEntity.recipe = nil (nullify)
  favoriteIDs still accurate → heart icons on list cards remain correct
  favorites: [Recipe] temporarily empty → Favorites tab shows loading state

Next fetch:
  RecipePersistenceService.save() re-links orphaned FavoriteEntity
  NSManagedObjectContextDidSave fires → FavoritesService.loadFavorites()
  Favorites tab restores full recipe data automatically
```

This is the same pattern used by production apps like Spotify and Apple Music — the "saved" marker is a lightweight record; the content is always fetched fresh and matched back.

---

## Dependency Injection vs. @EnvironmentObject: A Conscious Decision

After the CoreData-backed `FavoritesService` was implemented, an initial refactor passed the service into views as an `@EnvironmentObject` — a common SwiftUI pattern for "global" objects. This was quickly challenged.

### > The `@EnvironmentObject` Question

> *"I saw that the favorite service is still being the EnvironmentObject. I thought we agreed that it should be injected as dependency instead."*

This observation identified a real architectural inconsistency: the code had a testable protocol (`FavoritesServiceProtocol`) but was still using `@EnvironmentObject` to distribute the concrete type, which bypasses the protocol entirely. When pressed further on long-term implications:

> *"If we talk about long-term maintainability and scalability, will this approach still be OK compared with explicit DI?"*

The honest answer was **no**. `@EnvironmentObject` has specific problems that compound over time:

| Problem | Impact |
| --- | --- |
| Requires the **concrete type**, not a protocol | You cannot inject a mock at test time without workarounds |
| **Runtime crash** if the object is missing from the environment | Caught only at runtime, not at compile time |
| **Hidden dependency** — the view's requirements are not visible in its initializer | A new team member cannot see what a view needs without searching the body for `.environmentObject` calls |
| **Singleton coupling** — every view that reads `FavoritesService` is now coupled to `FavoritesService.shared` | Multi-window, deep-link, and notification entry points all share one global instance |

### The Chosen Approach — Explicit DI through the ViewModel

The decision was made to keep `@EnvironmentObject` out of the architecture entirely. The design:

1. **`FavoritesServiceProtocol`** — a `@MainActor` protocol exposing `AnyPublisher` properties, so the ViewModel can subscribe without holding a concrete `ObservableObject`
2. **`RecipeListViewModel` holds `any FavoritesServiceProtocol`** — injected at init, defaulting to `FavoritesService.shared` for production and accepting `MockFavoritesService` in tests
3. **Publisher bridge via `assign(to: &$property)`** — the ViewModel subscribes to the service's publishers and forwards values into its own `@Published` properties; views observe only the ViewModel
4. **`RecipeGridCard` is a pure presentational component** — accepts `isFavorited: Bool` and `onToggle: () -> Void`; has zero knowledge of services or the ViewModel
5. **`RecipeDetailView` receives `@ObservedObject var viewModel: RecipeListViewModel`** — the dependency is visible in the type signature, not hidden in the environment

```swift
// ViewModel init — dependency visible at the call site
RecipeListViewModel(
    recipeService: mockService,
    persistenceService: StubPersistenceService(),
    favoritesService: MockFavoritesService()   // ← swapped for tests, one line
)
```

```swift
// RecipeGridCard — zero service knowledge
RecipeGridCard(
    recipe: recipe,
    isFavorited: viewModel.isFavorite(recipe.id),
    onToggle: { Task { await viewModel.toggleFavorite(recipe) } }
)
```

### Why This Scales Better

- **Testability:** `MockFavoritesService` is a plain `@MainActor final class` with `CurrentValueSubject` publishers. Injecting it requires no `environmentObject` modifiers, no special `UIHostingController` setup, and no test-specific app state.
- **Navigability:** The dependency graph is traceable from the type system. `RecipeDetailView` visibly requires a `RecipeListViewModel`.
- **Extensibility:** Adding a second screen (e.g., a widget or share extension) that needs favorites requires passing the same `FavoritesService` instance to a new ViewModel — no global environment plumbing.
- **Correctness:** The compiler enforces that every `RecipeDetailView` has a ViewModel. There is no category of `Thread 1: Fatal error: No ObservableObject of type FavoritesService found` crashes.

---

## CoreData Schema Versioning

The schema is defined programmatically in `CoreDataStack.managedObjectModel`. A `currentModelVersion` integer and a `migrationSteps` registry track every change:

| Version | Change | Policy |
| --- | --- | --- |
| v1 | Initial schema (`isVegetarian Bool`) | — |
| v2 | Replaced `isVegetarian` with `dietaryAttributesData ([String] as Data)` | Wipe |
| v3 | Added `FavoriteEntity` with one-to-many relationship to `RecipeEntity` | Wipe |

`.wipe` migrations are safe here because CoreData is used as a re-fetchable network cache. User-generated data (`FavoriteEntity`) uses `.nullifyDeleteRule` on the relationship so favorites are never caught in a cache wipe.

---

## Testing

Tests live in `RecipeAppExamTests/` and use **Swift Testing** (`@Test`, `@Suite`). Each test file maps 1-to-1 to the production file it covers. Shared fixtures and test doubles live in `Support/`.

```text
RecipeAppExamTests/
├── Support/
│   ├── Fixtures.swift                  — sampleRecipes, twentyRecipes
│   └── Mocks.swift                     — MockNetworkService, FailingNetworkService,
│                                         StubPersistenceService, MockFavoritesService
├── RecipeTests.swift                   — Recipe model
├── RecipeFilterTests.swift             — RecipeFilter
├── DietaryAttributeTests.swift         — DietaryAttribute
├── PaginatedResponseTests.swift        — PaginatedResponse
├── NetworkServiceTests.swift           — NetworkError, APIEndpoint
├── RecipeServiceTests.swift            — RecipeService fetch/search, IngredientExtraction
├── RecipePersistenceServiceTests.swift — RecipePersistenceService
├── FavoritesServiceTests.swift         — FavoritesService
└── RecipeListViewModelTests.swift      — RecipeListViewModel
```

| File | Suite(s) | What it covers |
| --- | --- | --- |
| `RecipeTests.swift` | `RecipeModelTests` | Codable round-trip, Hashable, Identifiable, JSON key mapping |
| `RecipeFilterTests.swift` | `RecipeFilterTests` | `isActive`, `activeFilterCount`, dietary/servings/ingredient combinations |
| `DietaryAttributeTests.swift` | `DietaryAttributeTests` | `displayName`, `systemImage`, `rawValue` round-trips |
| `PaginatedResponseTests.swift` | `PaginatedResponseTests` | `hasNextPage`, metadata fields |
| `NetworkServiceTests.swift` | `NetworkErrorTests`, `APIEndpointTests` | All `NetworkError` cases, `resourceName` and `path` for each endpoint |
| `RecipeServiceTests.swift` | `RecipeServiceTests`, `IngredientExtractionTests` | Fetch pagination, text search, dietary/servings/ingredient filtering, ingredient name parsing |
| `RecipePersistenceServiceTests.swift` | `RecipePersistenceServiceTests` | Save, fetch, upsert-by-ID, `deleteAll`, imageURL and dietary round-trips |
| `FavoritesServiceTests.swift` | `FavoritesServiceTests` | Toggle add/remove, `isFavorite`, persistence across instances (shared CoreData stack) |
| `RecipeListViewModelTests.swift` | `RecipeListViewModelTests` | Initial state, load, pagination, error handling, cache fallback, filter, favorites via `MockFavoritesService` |

### Testability Patterns

- `RecipeListViewModel` accepts injected `RecipeServiceProtocol`, `RecipePersistenceServiceProtocol`, `ConnectivityMonitor`, and `FavoritesServiceProtocol` — no real network, disk, or CoreData I/O in tests.
- `MockNetworkService` (in `Support/Mocks.swift`) stands in for `NetworkService` in unit tests — same `NetworkServiceProtocol` contract, returns preset fixture data instead of hitting the network or the bundle.
- `FailingNetworkService` always throws `NetworkError.networkUnavailable`, covering error and cache-fallback branches.
- `MockFavoritesService` is a `@MainActor final class` conforming to `FavoritesServiceProtocol`, backed by `CurrentValueSubject`. Injected directly into the ViewModel constructor — no `environmentObject` modifiers or test-specific app state required.
- `FavoritesService.makeForTesting()` creates an isolated instance backed by a fresh in-memory `CoreDataStack`.
- `FavoritesService.makeForTesting(coreDataStack:)` allows two instances to share a stack for persistence round-trip tests.
- `StubPersistenceService` is an in-memory array conforming to `RecipePersistenceServiceProtocol`.

---

## Assumptions & Tradeoffs

- **Dual-mode `NetworkService`.** By default (no `baseURL`), data comes from `recipes.json` bundled with the app and a 400 ms simulated latency exposes loading states during development. Passing a `baseURL` switches the same class to real `URLSession` HTTP requests — no other code changes are needed. `NetworkError.serverError(statusCode:)` handles non-2xx responses in live mode.
- **Single JSON source.** All 20 recipes are in one flat file. The service layer pages results in memory. A real API would expose a paginated endpoint; only the `NetworkService` initialiser call changes.
- **CoreData over SwiftData.** The requirements explicitly requested CoreData with strict concurrency practices. SwiftData was intentionally avoided. -> This is because: 1) SwiftData is still new so resources in the community might be limite; 2) SwiftData's `@Model` types are not `Sendable`, which complicates the ViewModel's async operations and requires `@unchecked Sendable` annotations. CoreData with `context.perform { }` provides a clean concurrency model without these issues; and 3) SwiftData does not support batch deleting so that will be a performance bottleneck for cache clears as the dataset grows
- **In-memory ingredient prefetch.** `RecipeListViewModel.prefetchIngredientNames()` calls `fetchRecipes(page:1, pageSize:1000)` to build the ingredient chip list. With a real API, this would be a dedicated endpoint
- **Search semantics.** Text search is OR across title/description/instructions. Ingredient include filters use AND semantics (recipe must contain all selected ingredients). This matches the most intuitive user expectation and is documented in `RecipeFilter`.

---

## Known Limitations

- Offline mode surfaces the last unfiltered page set that was fetched. Filtered results are not persisted to cache.
- There are no system for clearing saved image cache
- `MockNetworkService` in tests assumes `T == [Recipe]`. A new endpoint returning a different type requires an additional stub or a generic fixture.
- UI tests (`RecipeAppExamUITests`) are scaffolded but not populated. They should be added once a design system is finalized.
- `favoriteRecipes` on `FavoritesService` may briefly appear empty after a cold launch if the recipe cache has been cleared — it restores as soon as the first fetch completes and `RecipePersistenceService.save()` re-links the relationships.
