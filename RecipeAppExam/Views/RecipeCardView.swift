// Views/RecipeCardView.swift

import SwiftUI

// MARK: - ImageCacheService

/// Two-tier image cache: in-memory for instant recall within a session,
/// disk-backed for persistence across app restarts.
/// Actor isolation makes both caches safe to access from any async context.
actor ImageCacheService {

    static let shared = ImageCacheService()

    private var memoryCache: [String: UIImage] = [:]
    private let directory: URL

    private init() {
        let base = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.recipeapp.images", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    func image(for urlString: String) async throws -> UIImage {
        // 1. Memory hit — fastest path, no I/O
        if let cached = memoryCache[urlString] { return cached }

        // 2. Disk hit — survives app restarts and session bounces
        let filePath = directory.appendingPathComponent(cacheKey(for: urlString))
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            memoryCache[urlString] = image
            return image
        }

        // 3. Network fetch — only runs once per unique URL
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }

        memoryCache[urlString] = image
        try? data.write(to: filePath, options: .atomic)
        return image
    }

    private func cacheKey(for urlString: String) -> String {
        let sanitized = urlString
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return String(sanitized.prefix(120))
    }
}

// MARK: - RecipeCardView

struct RecipeCardView: View {

    let recipe: Recipe
    private let maxVisibleBadges = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Hero image
            RecipeImageView(urlString: recipe.imageURL, height: 180)

            // MARK: Content
            VStack(alignment: .leading, spacing: 8) {

                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(recipe.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if !recipe.dietaryAttributes.isEmpty {
                    DietaryBadgeRowView(
                        attributes: recipe.dietaryAttributes,
                        maxVisible: maxVisibleBadges
                    )
                }

                HStack(spacing: 12) {
                    Label("\(recipe.servings) servings", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("\(recipe.ingredients.count) ingredients", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

// MARK: - RecipeGridCard

/// Compact two-column grid card with a heart-overlay for the favorites feature.
/// Receives `isFavorited` and `onToggle` as plain parameters — no environment
/// dependencies. This makes the component self-contained, trivially previewable,
/// and usable in any context without injecting services.
struct RecipeGridCard: View {

    let recipe: Recipe
    let isFavorited: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            ZStack(alignment: .topTrailing) {
                RecipeImageView(urlString: recipe.imageURL, height: 160)

                Button(action: onToggle) {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isFavorited ? .red : .white)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Label("\(recipe.servings) servings", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
    }
}

// MARK: - RecipeImageView

/// Shared image component with two-tier caching.
/// Memory cache prevents flicker on scroll; disk cache persists across restarts.
struct RecipeImageView: View {

    let urlString: String?
    var height: CGFloat = 200

    @State private var loadedImage: UIImage?
    @State private var isFailed = false

    var body: some View {
        Group {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            } else if isFailed {
                imagePlaceholder
            } else {
                imagePlaceholder
                    .overlay { ProgressView().tint(.white) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .clipped()
        .task(id: urlString) {
            await loadImage()
        }
    }

    private func loadImage() async {
        loadedImage = nil
        isFailed = false
        guard let urlString else { isFailed = true; return }
        do {
            let image = try await ImageCacheService.shared.image(for: urlString)
            guard !Task.isCancelled else { return }
            loadedImage = image
        } catch {
            guard !Task.isCancelled else { return }
            isFailed = true
        }
    }

    private var imagePlaceholder: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.75), Color.accentColor.opacity(0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "fork.knife")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - DietaryBadgeRowView

/// Shows up to `maxVisible` attribute chips, then a "+N" overflow pill.
struct DietaryBadgeRowView: View {

    let attributes: [String]
    var maxVisible: Int = 3

    private var visible: [String] { Array(attributes.prefix(maxVisible)) }
    private var overflow: Int { max(0, attributes.count - maxVisible) }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(visible, id: \.self) { raw in
                DietaryBadgeView(rawValue: raw)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}

// MARK: - DietaryBadgeView

/// Single colored pill for one dietary attribute.
struct DietaryBadgeView: View {

    let rawValue: String

    private var attribute: DietaryAttribute? { rawValue.asDietaryAttribute }

    var body: some View {
        HStack(spacing: 3) {
            if let attribute {
                Image(systemName: attribute.systemImage)
            }
            Text(attribute?.displayName ?? rawValue.capitalized)
        }
        .font(.caption2.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(attribute?.color ?? .gray, in: Capsule())
        .accessibilityLabel(attribute?.displayName ?? rawValue)
    }
}

// MARK: - Preview

#Preview("Grid Cards") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            RecipeGridCard(recipe: .preview, isFavorited: false, onToggle: {})
            RecipeGridCard(recipe: .previewMultiDietary, isFavorited: true, onToggle: {})
            RecipeGridCard(recipe: .preview, isFavorited: false, onToggle: {})
            RecipeGridCard(recipe: .previewMultiDietary, isFavorited: true, onToggle: {})
        }
        .padding(16)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("List Card") {
    List {
        RecipeCardView(recipe: .preview)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        RecipeCardView(recipe: .previewMultiDietary)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
    .listStyle(.insetGrouped)
}

// MARK: - Preview helpers

extension Recipe {
    static let preview = Recipe(
        id: "1",
        title: "Classic Margherita Pizza",
        description: "A timeless Italian pizza with fresh mozzarella, tomatoes, and basil.",
        servings: 4,
        ingredients: ["Flour", "Tomato sauce", "Mozzarella", "Basil"],
        instructions: ["Mix dough", "Add toppings", "Bake at 475°F"],
        dietaryAttributes: ["vegetarian", "nut-free"],
        imageURL: "https://picsum.photos/seed/pizza-margherita/800/600"
    )

    static let previewMultiDietary = Recipe(
        id: "17",
        title: "Spinach & Chickpea Curry",
        description: "Hearty plant-based curry with wilted spinach and spiced chickpeas in a tomato base.",
        servings: 4,
        ingredients: ["Chickpeas", "Spinach", "Tomatoes", "Spices"],
        instructions: ["Sauté onion", "Add spices", "Simmer"],
        dietaryAttributes: ["vegan", "vegetarian", "plant-based", "gluten-free", "dairy-free / lactose-free"],
        imageURL: "https://picsum.photos/seed/chickpea-curry/800/600"
    )
}
