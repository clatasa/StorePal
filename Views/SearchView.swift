internal import SwiftUI
import MapKit

struct SearchView: View {
    @EnvironmentObject var viewModel: StoreViewModel
    @Environment(\.dismiss) var dismiss
    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Full-screen interactive map
                Map(position: $mapPosition) {
                    UserAnnotation()
                    ForEach(viewModel.searchResults) { store in
                        Marker(store.name, coordinate: store.coordinate)
                            .tint(viewModel.favoriteIds.contains(store.id) ? .yellow : .blue)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .ignoresSafeArea(edges: .top)

                // Results panel
                resultsPanel
            }
            .navigationTitle("Find Stores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSearching {
                        ProgressView()
                    } else {
                        Button("Search Here") {
                            Task { await viewModel.searchNearby() }
                        }
                    }
                }
            }
        }
        .task { await viewModel.searchNearby() }
        // Show error as alert
        .alert("Search Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Results panel

    private var resultsPanel: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)

            if viewModel.isSearching {
                ProgressView("Searching for stores…")
                    .padding(.vertical, 20)

            } else if viewModel.searchResults.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "mappin.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No stores found nearby")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 20)

            } else {
                // Capacity warning
                if !viewModel.canAddFavorite {
                    Label("All 3 slots filled. Remove a store to add another.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.searchResults) { store in
                            StoreRow(
                                store: store,
                                isFavorite: viewModel.favoriteIds.contains(store.id),
                                canAdd: viewModel.canAddFavorite,
                                onToggle: { viewModel.toggleFavorite(store) }
                            )
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
