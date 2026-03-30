internal import SwiftUI
import MapKit

struct HomeView: View {
    @EnvironmentObject var viewModel: StoreViewModel
    @State private var showSearch   = false
    @State private var showSettings = false
    @State private var miniMapPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    miniMapCard
                    favoritesCard
                }
                .padding()
            }
            .navigationTitle("StorePal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSearch = true } label: {
                        Label("Find Stores", systemImage: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchView().environmentObject(viewModel)
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet().environmentObject(viewModel)
            }
        }
        .task {
            await viewModel.requestPermissions()
            viewModel.locationService.startUpdatingLocation()
        }
        // Update mini map when favorites change
        .onChange(of: viewModel.favorites) { updateMiniMapPosition() }
        // Update mini map when location first arrives (no favorites yet)
        .onChange(of: viewModel.locationService.currentLocation) {
            if viewModel.favorites.isEmpty { updateMiniMapPosition() }
        }
    }

    // MARK: - Mini map card

    private var miniMapCard: some View {
        Map(position: $miniMapPosition, interactionModes: []) {
            UserAnnotation()
            ForEach(viewModel.favorites) { store in
                Marker(store.name, systemImage: "star.fill", coordinate: store.coordinate)
                    .tint(.yellow)
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls { }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            geofenceBadge.padding(10)
        }
        .overlay(alignment: .bottomLeading) {
            if viewModel.favorites.isEmpty {
                Button { showSearch = true } label: {
                    Label("Find Stores", systemImage: "magnifyingglass")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.blue, in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding(10)
            }
        }
    }

    private var geofenceBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(viewModel.favorites.isEmpty ? Color.secondary : .green)
                .frame(width: 7, height: 7)
            Text(viewModel.favorites.isEmpty ? "No alerts set" : "Alerts active")
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Favorites card

    private var favoritesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("My Stores")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.favorites.count) / 3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            if viewModel.favorites.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "star.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No saved stores yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tap the search icon to find stores nearby.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ForEach(viewModel.favorites) { store in
                    StoreRow(
                        store: store,
                        isFavorite: true,
                        canAdd: true,
                        onToggle: { viewModel.toggleFavorite(store) }
                    )
                    if store != viewModel.favorites.last {
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Mini map position helper

    private func updateMiniMapPosition() {
        let favs = viewModel.favorites

        if favs.isEmpty {
            if let loc = viewModel.locationService.currentLocation {
                miniMapPosition = .region(MKCoordinateRegion(
                    center: loc.coordinate,
                    latitudinalMeters: 3000,
                    longitudinalMeters: 3000
                ))
            }
            return
        }

        if favs.count == 1 {
            miniMapPosition = .region(MKCoordinateRegion(
                center: favs[0].coordinate,
                latitudinalMeters: 2000,
                longitudinalMeters: 2000
            ))
            return
        }

        let lats = favs.map { $0.latitude }
        let lngs = favs.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude:  (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  max((lats.max()! - lats.min()!) * 2.2, 0.02),
            longitudeDelta: max((lngs.max()! - lngs.min()!) * 2.2, 0.02)
        )
        miniMapPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

// MARK: - Reusable store row (used in both HomeView and SearchView)

struct StoreRow: View {
    let store: GroceryStore
    let isFavorite: Bool
    let canAdd: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.name)
                    .font(.body.weight(.medium))
                Text(store.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onToggle) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
                    .imageScale(.large)
                    .animation(.bouncy, value: isFavorite)
            }
            .buttonStyle(.plain)
            .disabled(!isFavorite && !canAdd)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}
