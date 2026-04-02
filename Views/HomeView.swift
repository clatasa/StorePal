internal import SwiftUI
import MapKit

struct HomeView: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var viewModel: StoreViewModel
    @State private var showSearch   = false
    @State private var showSettings = false
    
    @ObservedObject private var locationService = LocationService.shared
    @State private var selectedList: GroceryList?
    @State private var storeForRadiusEdit: GroceryStore?
    @State private var showAddList  = false
    @State private var newListName     = ""
    @State private var miniMapPosition: MapCameraPosition = .automatic
    @State private var selectedMapStore: GroceryStore?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    miniMapCard
                    listsCard
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
            .sheet(item: $selectedList) { list in
                ListDetailView(listId: list.id)
                    .environmentObject(listViewModel)
                    .environmentObject(viewModel)
            }
            .sheet(item: $storeForRadiusEdit) { store in
                StoreRadiusSheet(store: store, defaultRadius: viewModel.geofenceRadius)
                    .environmentObject(viewModel)
            }
            // Add list alert
            .alert("New List", isPresented: $showAddList) {
                TextField("List name", text: $newListName)
                Button("Create") {
                    let trimmed = newListName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { listViewModel.addList(name: trimmed) }
                    newListName = ""
                }
                Button("Cancel", role: .cancel) { newListName = "" }
            }
        }
        .task {
            await viewModel.requestPermissions()
            viewModel.locationService.startUpdatingLocation()
        }
        .onChange(of: viewModel.favorites) { updateMiniMapPosition() }
        .onChange(of: viewModel.locationService.currentLocation) {
            if viewModel.favorites.isEmpty { updateMiniMapPosition() }
        }
        .onChange(of: selectedList) { _, newValue in
            if newValue == nil {
                selectedMapStore = nil
                updateMiniMapPosition()
            }
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
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - My Stores card

    private var favoritesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("My Stores")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.favorites.count) / \(viewModel.maxFavorites)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            if viewModel.favorites.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "star.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No saved stores yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tap the search icon to find stores nearby.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ForEach(sortedFavorites) { store in
                    let storeBoundLists = listViewModel.lists.filter { $0.boundStoreId == store.id }
                    StoreRow(
                        store: store,
                        isFavorite: true,
                        canAdd: true,
                        onToggle: { viewModel.toggleFavorite(store) },
                        isSelected: selectedMapStore?.id == store.id,
                        onTap: {
                            withAnimation {
                                if selectedMapStore?.id == store.id {
                                    selectedMapStore = nil
                                    updateMiniMapPosition()
                                } else {
                                    selectedMapStore = store
                                    miniMapPosition = .region(MKCoordinateRegion(
                                        center: store.coordinate,
                                        latitudinalMeters: 1500,
                                        longitudinalMeters: 1500
                                    ))
                                }
                            }
                        },
                        boundLists: storeBoundLists.map { list in (name: list.name, action: { selectedList = list }) }
                    )
                    .contextMenu {
                        Button {
                            storeForRadiusEdit = store
                        } label: {
                            Label(
                                store.geofenceRadiusOverride != nil ? "Edit Custom Radius" : "Set Custom Radius",
                                systemImage: "location.circle"
                            )
                        }
                        Divider()
                        Button(role: .destructive) {
                            viewModel.toggleFavorite(store)
                        } label: {
                            Label("Remove from Saved", systemImage: "star.slash")
                        }
                    }
                    if store != sortedFavorites.last {
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - My Lists card

    private var listsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("My Lists")
                    .font(.headline)
                Spacer()
                Button {
                    newListName = ""
                    showAddList = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                        .imageScale(.large)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            if listViewModel.lists.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No lists yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tap + to create your first list.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ForEach(listViewModel.lists) { list in
                    Button { selectedList = list } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(list.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                let n = list.activeCount
                                Text(n == 0 ? "All done" : "\(n) item\(n == 1 ? "" : "s") remaining")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let storeName = viewModel.favorites.first(where: { $0.id == list.boundStoreId })?.name {
                                    Label(storeName, systemImage: "storefront")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            listViewModel.deleteList(list)
                        } label: {
                            Label("Delete List", systemImage: "trash")
                        }
                    }
                    if list != listViewModel.lists.last {
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Distance-sorted stores (display only)

    private var sortedFavorites: [GroceryStore] {
        guard let location = viewModel.locationService.currentLocation else {
            return viewModel.favorites
        }
        return viewModel.favorites.sorted {
            location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) <
            location.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
        }
    }

    // MARK: - Mini map position helper

    private func updateMiniMapPosition() {
        guard selectedMapStore == nil else { return }
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

// MARK: - Reusable store row (used in HomeView and SearchView)

struct StoreRow: View {
    let store: GroceryStore
    let isFavorite: Bool
    let canAdd: Bool
    let onToggle: () -> Void
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    /// All lists bound to this store (name + tap action each).
    var boundLists: [(name: String, action: () -> Void)] = []

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.name)
                    .font(.body.weight(.medium))
                Text(store.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ForEach(boundLists.indices, id: \.self) { i in
                    Button(action: boundLists[i].action) {
                        Label(boundLists[i].name, systemImage: "list.bullet")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            Button(action: onToggle) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
                    .imageScale(.large)
                    .animation(.bouncy, value: isFavorite)
            }
            .buttonStyle(.plain)
            .disabled(!isFavorite && !canAdd)
        }
        .contentShape(Rectangle())
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(isSelected ? Color.blue.opacity(0.07) : Color.clear)
    }
}

// MARK: - Store radius sheet

struct StoreRadiusSheet: View {
    let store: GroceryStore
    let defaultRadius: Double
    @EnvironmentObject var viewModel: StoreViewModel
    @AppStorage("useImperial") private var useImperial: Bool = false
    @Environment(\.dismiss) var dismiss

    @State private var hasOverride: Bool
    @State private var radius: Double

    init(store: GroceryStore, defaultRadius: Double) {
        self.store = store
        self.defaultRadius = defaultRadius
        _hasOverride = State(initialValue: store.geofenceRadiusOverride != nil)
        _radius = State(initialValue: store.geofenceRadiusOverride ?? defaultRadius)
    }

    private func formatRadius(_ meters: Double) -> String {
        useImperial ? String(format: "%.2f mi", meters * 0.000621371) : "\(Int(meters)) m"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Custom Radius", isOn: $hasOverride.animation())
                    if hasOverride {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Alert Radius")
                                Spacer()
                                Text(formatRadius(radius))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $radius, in: 100...2000, step: 50)
                                .tint(.blue)
                            HStack {
                                Text(useImperial ? "0.06 mi" : "100 m")
                                Spacer()
                                Text(useImperial ? "1.24 mi" : "2 km")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(store.name)
                } footer: {
                    if hasOverride {
                        Text("This store will alert you within \(formatRadius(radius)), overriding the global setting.")
                    } else {
                        Text("Using the global radius (\(formatRadius(defaultRadius))). Enable to set a custom radius for this store only.")
                    }
                }
            }
            .navigationTitle("Alert Radius")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.setRadiusOverride(for: store.id, radius: hasOverride ? radius : nil)
                        dismiss()
                    }
                }
            }
        }
    }
}
