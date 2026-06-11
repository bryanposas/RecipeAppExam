// Views/RecipeListView.swift

import SwiftUI

// MARK: - RecipeTab

private enum RecipeTab: String, CaseIterable {
    case discover = "Discover"
    case favorites = "Favorites"

    var icon: String {
        switch self {
        case .discover: return "fork.knife.circle"
        case .favorites: return "heart"
        }
    }
}

// MARK: - RecipeListView

struct RecipeListView: View {

    @StateObject private var viewModel = RecipeListViewModel()

    @State private var navigationPath = NavigationPath()
    @State private var selectedTab: RecipeTab = .discover
    @State private var isFilterSheetPresented = false
    @State private var isOfflineBannerDismissed = false

    private let columns = [GridItem(.flexible())]

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                headerArea

                ZStack(alignment: .top) {
                    Group {
                        switch selectedTab {
                        case .discover: discoverContent
                        case .favorites: favoritesContent
                        }
                    }

                    if viewModel.isOffline && !isOfflineBannerDismissed {
                        OfflineBannerView(isDismissed: $isOfflineBannerDismissed)
                            .zIndex(1)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.3), value: viewModel.isOffline)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe, viewModel: viewModel)
            }
            .sheet(isPresented: $isFilterSheetPresented) {
                SearchFilterView(
                    filter: $viewModel.filter,
                    availableIngredients: viewModel.allIngredientNames
                )
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )) {
                Button("Retry") { Task { await viewModel.loadRecipes() } }
                Button("Dismiss", role: .cancel) { viewModel.dismissError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .task { await viewModel.loadRecipes() }
        .onChange(of: viewModel.isOffline) { _, isOffline in
            if isOffline { isOfflineBannerDismissed = false }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerArea: some View {
        VStack(spacing: 0) {
            tabControl
            Divider()
            searchRow
            Divider()
        }
        .background(Color.appSurfaceColor)
    }

    private var tabControl: some View {
        HStack(spacing: 0) {
            ForEach(RecipeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon).font(.subheadline)
                            Text(tab.rawValue)
                                .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                        }
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("Search recipes…", text: $viewModel.filter.searchQuery)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !viewModel.filter.searchQuery.isEmpty {
                    Button {
                        viewModel.filter.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.appSurfaceColor, in: RoundedRectangle(cornerRadius: 12))

            filterButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var filterButton: some View {
        Button {
            isFilterSheetPresented = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17))
                    .padding(10)
                    .background(
                        viewModel.filter.activeFilterCount > 0
                            ? Color.accentColor
                            : Color.appSurfaceColor,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .foregroundStyle(viewModel.filter.activeFilterCount > 0 ? .white : .primary)

                if viewModel.filter.activeFilterCount > 0 {
                    Text("\(viewModel.filter.activeFilterCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.red, in: Circle())
                        .offset(x: 5, y: -5)
                }
            }
        }
        .accessibilityLabel(
            viewModel.filter.activeFilterCount > 0
                ? "Filters active (\(viewModel.filter.activeFilterCount))"
                : "Filters"
        )
    }

    // MARK: - Discover tab

    @ViewBuilder
    private var discoverContent: some View {
        if viewModel.isLoading && viewModel.recipes.isEmpty {
            loadingView
        } else if viewModel.recipes.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.recipes) { recipe in
                        Button {
                            navigationPath.append(recipe)
                        } label: {
                            RecipeGridCard(
                                recipe: recipe,
                                isFavorited: viewModel.isFavorite(recipe.id),
                                onToggle: { Task { await viewModel.toggleFavorite(recipe) } }
                            )
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            Task { await viewModel.loadNextPageIfNeeded(currentItem: recipe) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                if viewModel.isLoading {
                    ProgressView().padding(.bottom, 20)
                }
            }
            .background(Color.appBackgroundColor)
            .refreshable { await viewModel.loadRecipes() }
        }
    }

    // MARK: - Favorites tab

    @ViewBuilder
    private var favoritesContent: some View {
        if viewModel.favoriteRecipes.isEmpty {
            emptyFavoritesView
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.favoriteRecipes) { recipe in
                        Button {
                            navigationPath.append(recipe)
                        } label: {
                            RecipeGridCard(
                                recipe: recipe,
                                isFavorited: true,
                                onToggle: { Task { await viewModel.toggleFavorite(recipe) } }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
            .background(Color.appBackgroundColor)
        }
    }

    // MARK: - State views

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading recipes…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackgroundColor)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(viewModel.filter.isActive ? "No recipes match your filters." : "No recipes available.")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if viewModel.filter.isActive {
                Button("Clear Filters") { viewModel.filter = RecipeFilter() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackgroundColor)
    }

    @ViewBuilder
    private var emptyFavoritesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No favorites yet.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap the heart on any recipe to save it here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackgroundColor)
    }
}

// MARK: - Preview

#Preview {
    RecipeListView()
}
