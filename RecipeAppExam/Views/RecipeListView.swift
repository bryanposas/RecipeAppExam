// Views/RecipeListView.swift

import SwiftUI

// MARK: - RecipeListView

struct RecipeListView: View {

    @StateObject private var viewModel = RecipeListViewModel()

    @State private var navigationPath = NavigationPath()
    @State private var isFilterSheetPresented: Bool = false
    @State private var isOfflineBannerDismissed: Bool = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                recipeList

                if viewModel.isOffline && !isOfflineBannerDismissed {
                    OfflineBannerView(isDismissed: $isOfflineBannerDismissed)
                        .zIndex(1)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isOffline)
                }
            }
            .navigationTitle("Recipes")
            .searchable(
                text: $viewModel.filter.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search recipes, ingredients…"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterButton
                }
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(isPresented: $isFilterSheetPresented) {
                SearchFilterView(filter: $viewModel.filter)
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

    // MARK: - Subviews

    @ViewBuilder
    private var recipeList: some View {
        Group {
            if viewModel.isLoading && viewModel.recipes.isEmpty {
                loadingView
            } else if viewModel.recipes.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(viewModel.recipes) { recipe in
                        Button {
                            navigationPath.append(recipe)
                        } label: {
                            RecipeCardView(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .task {
                            await viewModel.loadNextPageIfNeeded(currentItem: recipe)
                        }
                    }

                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.loadRecipes()
                }
            }
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading recipes…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Button("Clear Filters") {
                    viewModel.filter = RecipeFilter()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var filterButton: some View {
        Button {
            isFilterSheetPresented = true
        } label: {
            Image(systemName: viewModel.filter.isActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityLabel(viewModel.filter.isActive ? "Filters active" : "Filters")
    }
}

// MARK: - Preview

#Preview {
    RecipeListView()
}
