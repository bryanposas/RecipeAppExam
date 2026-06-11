# GitHub Copilot Instructions

## Project Overview

- **Platform**: iOS  
- **Minimum Deployment Target**: iOS 26+  
- **Language**: Swift 6.x  
- **UI Framework**: SwiftUI  
- **Lifecycle**: Scene App Delegate  
- **Architecture**: MVVM  

## Project Structure

ProjectName/

├── README.md

├── SceneDelegate.swift

├── Controllers/        \# UIViewControllers

├── Views/              \# Custom UIView subclasses, XIBs

├── Models/             \# Data models and entities

├── Services/           \# Networking, persistence, business logic

├── Extensions/         \# Swift extensions

├── Resources/          \# Assets, fonts, plists

└── Supporting Files/   \# Info.plist, etc.

## Functional Requirements

### General

- Build a **native iOS application** using **Swift and SwiftUI** that allows users to browse and search a collection of cooking recipes.  
- Each recipe contains:  
* Title  
* Description  
* Number of servings  
* Ingredients  
* Cooking instructions  
* Dietary attributes (e.g. vegetarian)  
- The app should load data from a mock API response (local JSON file) and present recipes in a clean, intuitive interface with search and filtering capabilities  
- Must Design Recipe Model  
* Define and implement Recipe model  
* Load recipes from a local JSON file bundled with the app  
* Structure the code as if the data were coming from a real API  
- Create Views & View Models  
* Present recipes in a clean, intuitive interface  
* Display a list or grid of recipes  
- Must Build Search Feature  
  - Implement a **search endpoint** with optional query filters:  
    * Vegetarian filter  
    * Servings filter  
    * Include/exclude ingredients  
    * Instruction content search

### Objective / Task Description

- When reviewing the coding challenge, we will also be looking at coding style, design intuition, and developer mindset. These include, but not limited to:  
* Logical and intuitive user experience  
* Use of frameworks and leveraging SwiftUI idioms  
* Naming conventions  
* Documentation of any assumptions or unclear boundaries  
* Handling of errors and/or constraints were needed

## Technical Requirements

### General

- Must be implemented purely in Swift and SwiftUI  
- The development environment is Test Driven Development which means that business logics and functions must have corresponding unit tests to ensure reliability and stability  
- The code must be readable, scalable, maintainable, and extendable. Must include comments to document how it became scalable and maintainable  
- The system should be **maintainable and extendable**:  
1. clear relationship between parts of the code  
2. code is simple, readable, and easy to understand  
3. new functionality can be added without rewriting existing components  
4. adding new currencies should be straightforward  
- Should follow best practices and ensure separation of concerns with regard to MVVM as the architectural pattern using observable objects, state  
- Must adhere to MVVM but without the help of third party libraries offering reactive programming functionalities and it must follow the best practices and ensure separation of concerns  
- Must use previews  
- Mock API response using .json file with capability for pagination  
- Must create a network layer whose responsibility is to handle api calls and in this project, it must mock receiving the json response from an api  
- Must create a persistence layer using CoreData with strict adherence to best practices with regard to concurrency or data racing conditions  
- Must provide some offline capabilities such as displaying of a dismissable floater showing internet connection issue error  
- Must have pagination capabilities corresponding to the mock json api response

## Coding Conventions

### General

- Use Swift idioms: optionals, guard, result types  
- Prefer `final class` for view controllers unless subclassing is intended  
- Use `private` and `private(set)` to limit scope  
- Avoid force-unwraps (`!`); use `guard let` or `if let`  
- Use `// MARK: -` to organize code sections  
- Must follow the current best practices such as but not limited to, the SOLID principle, linting, and etc  
- Must follow best practices in relation to naming convention  
- Must lint the codes

### README

- Must provide clear instructions for setting up and running the project  
  1. Setup instructions  
  2. High-level architecture overview  
  3. Key design decisions  
  4. Assumptions and tradeoffs  
  5. Any known limitations

### UI

- The **UI** should be user-friendly, responsive, and clearly indicate background operations such as data loading  
- The UI must be intuitive, responsive, and has visually clear implementation  
- The **layout** should be responsive and work across all device sizes, including iPads, using Auto Layout.  
- UI Components must be separated into separate UI files to reduce lines of codes

### UIViewController

- Set up UI in `viewDidLoad`  
- Use `weak` references in delegates and closures to avoid retain cycles

### Networking

- Use `URLSession` for HTTP requests  
- Decode JSON using `Codable`  
- Handle errors explicitly; never silently swallow them

### Error Handling

- Provide proper **error handling** for network or data issues, ensuring stable app behavior in all cases.

### Naming

- ViewControllers: `HomeViewController`, `ProfileViewController`  
- Views: `UserCardView`, `LoadingView`  
- Delegates: `UserServiceDelegate`, `CartManagerDelegate`  
- Constants: use `enum` namespaces, e.g. `Constants.API.baseURL`

### Threading

- Always update UI on the main thread: `DispatchQueue.main.async { }`  
- Use `async/await` (Swift concurrency) for new async code where iOS version supports it

## Dependencies

- None yet  

## What to Avoid

- Do not introduce new third-party packages without noting them here  
- Avoid singleton abuse — prefer dependency injection

## Testing

- Unit test files go in `ProjectNameTests/`  
- UI test files go in `ProjectNameUITests/`  
- Use `XCTest`

