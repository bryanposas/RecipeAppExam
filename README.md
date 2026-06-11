# RecipeAppExam

A native iOS recipe browser built with **Swift + SwiftUI** following MVVM, CoreData persistence, a mock network layer, and TDD.

---

## Setup & Running

### Requirements

- Xcode 15.4 or later
- iOS 17.5 simulator or device
- No third-party dependencies — zero SPM packages required

### Open in Xcode

```bash
open RecipeAppExam.xcodeproj
```

Select any iOS 17.5+ simulator and press **Cmd+R**.

### Run tests

```bash
xcodebuild test \
  -project RecipeAppExam.xcodeproj \
  -scheme RecipeAppExam \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Architecture Overview

```text
RecipeAppExam/
├── Models/               # Pure value types — Recipe, PaginatedResponse, RecipeFilter
├── ViewModels/           # RecipeListViewModel (@MainActor ObservableObject)
├── Views/                # SwiftUI views — one component per file
├── Services/             # NetworkServiceProtocol + MockNetworkService, RecipeService, ConnectivityMonitor
├── Persistence/          # CoreDataStack, RecipeEntity, RecipePersistenceService
├── Resources/            # recipes.json (20 mock recipes)
└── Extensions/           # (reserved for future shared View helpers)
```

### MVVM Data Flow

```text
MockNetworkService → RecipeService → RecipeListViewModel → RecipeListView
                                           ↕
                              RecipePersistenceService ↔ CoreDataStack
```

---

## Key Design Decisions

| Decision | Rationale |
| --- | --- |
| `MockNetworkService` mirrors real `URLSession` interface | Swapping to a live service later requires only a new conforming type, not any ViewModel changes |
| Filtering done in-memory inside `RecipeService` | Avoids multiple JSON files; the service layer is the single point of truth for query logic, making it trivially testable |
| Pagination sliced at service layer | The JSON resource stays simple (flat array); pagination behaviour is tested in isolation |
| CoreData model defined in Swift code | Keeps schema in source control without a binary `.xcdatamodeld` bundle; entity changes are diffs |
| `@MainActor` on `RecipeListViewModel` | All `@Published` mutations are guaranteed to run on the main thread — no explicit `DispatchQueue.main.async` scattered through views |
| `context.perform { }` for all CoreData writes | Uses the async Swift concurrency variant (iOS 15+); serial queue per context prevents data races |
| `ConnectivityMonitor` via `NWPathMonitor` | Real-time path updates without polling; ViewModel subscribes via Combine `.assign(to:)` to avoid retain cycles |
| Debounced `$filter` observation (350 ms) | Prevents a network fetch on every keystroke while the user is still typing |

---

## Assumptions & Tradeoffs

- **No real network calls** — data comes from `recipes.json` bundled with the app. The `MockNetworkService` adds an artificial 400 ms delay to expose loading states during manual testing.
- **Single JSON file** — all 20 recipes are in one file. The service layer pages the results in memory. A real API would expose a paginated endpoint; only `MockNetworkService` would change.
- **CoreData over SwiftData** — the requirements explicitly request CoreData with strict concurrency practices. SwiftData (introduced in iOS 17) was intentionally avoided.
- **No image loading** — `imageURL` is present in the model and JSON but the UI shows a placeholder. Adding `AsyncImage` is straightforward once real URLs are provided.
- **Search is OR across title/description/instructions, AND across include-ingredients** — this matches the most intuitive user expectation. The filter struct documents each field's semantics.

---

## Known Limitations

- Offline mode shows the last full (unfiltered) page set that was fetched. Filtered results are not cached.
- The `StubNetworkService` in tests assumes `T == [Recipe]`. If a new endpoint returns a different type, an additional stub will be needed.
- UI tests (`RecipeAppExamUITests`) are scaffolded but not populated; they should be expanded once a design system is finalized.
