internal import SwiftUI
import MapKit

struct ListDetailView: View {
    let listId: UUID
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var storeViewModel: StoreViewModel
    @Environment(\.dismiss) var dismiss

    @State private var newItemName = ""
    @State private var showRenameAlert = false
    @State private var pendingRename = ""
    @FocusState private var isAddFieldFocused: Bool
    @State private var editMode: EditMode = .inactive
    @State private var itemToEdit: ListItem?
    @State private var isAddingDetailed = false
    @State private var showStorePicker = false

    private var list: GroceryList? {
        listViewModel.lists.first { $0.id == listId }
    }

    private var boundStore: GroceryStore? {
        guard let storeId = list?.boundStoreId else { return nil }
        return storeViewModel.favorites.first { $0.id == storeId }
    }

    private var hasCompletedItems: Bool {
        list?.items.contains { $0.isChecked } ?? false
    }

    var body: some View {
        NavigationStack {
            Group {
                if let list {
                    listContent(list)
                }
            }
            .navigationTitle(list?.name ?? "List")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(editMode == .active ? Color.blue : Color.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showStorePicker = true
                        } label: {
                            Label("Link to Store", systemImage: "storefront")
                        }
                        Divider()
                        Button {
                            pendingRename = list?.name ?? ""
                            showRenameAlert = true
                        } label: {
                            Label("Rename List", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            listViewModel.clearCompleted(from: listId)
                        } label: {
                            Label("Clear Completed", systemImage: "checkmark.circle")
                        }
                        .disabled(!hasCompletedItems)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Rename List", isPresented: $showRenameAlert) {
                TextField("List name", text: $pendingRename)
                Button("Save") {
                    let trimmed = pendingRename.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty, let list {
                        listViewModel.renameList(list, to: trimmed)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $itemToEdit) { item in
                ItemEditSheet(item: item, listId: listId, isNew: false)
                    .environmentObject(listViewModel)
            }
            .sheet(isPresented: $isAddingDetailed) {
                ItemEditSheet(item: nil, listId: listId, isNew: true)
                    .environmentObject(listViewModel)
            }
            .sheet(isPresented: $showStorePicker) {
                StorePickerSheet(
                    stores: storeViewModel.favorites,
                    currentStoreId: list?.boundStoreId,
                    onSelect: { storeId in listViewModel.bindList(listId, to: storeId) }
                )
            }
        }
    }

    // MARK: - List content

    @ViewBuilder
    private func listContent(_ list: GroceryList) -> some View {
        List {
            // Linked store banner
            if let store = boundStore {
                Section("Linked Store") {
                    Button {
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: store.coordinate))
                        item.name = store.name
                        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "storefront")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(store.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(store.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "arrow.triangle.turn.up.right.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            // Items section
            Section {
                if list.items.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "cart")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("No items yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Use the field below to add something.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 24)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(list.items) { item in
                        ItemRow(item: item, listId: listId, onTapEdit: { itemToEdit = item })
                            .environmentObject(listViewModel)
                    }
                    .onDelete { offsets in
                        offsets.map { list.items[$0] }.forEach {
                            listViewModel.deleteItem($0, from: listId)
                        }
                    }
                    .onMove { from, to in
                        listViewModel.moveItem(in: listId, from: from, to: to)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            addItemBar
        }
    }

    // MARK: - Add item bar

    private var addItemBar: some View {
        HStack(spacing: 12) {
            TextField("Add item…", text: $newItemName)
                .focused($isAddFieldFocused)
                .submitLabel(.done)
                .onSubmit { addItem() }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

            Button {
                isAddingDetailed = true
            } label: {
                Image(systemName: "text.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            Button(action: addItem) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        newItemName.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.secondary
                            : Color.blue
                    )
            }
            .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func addItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        listViewModel.addItem(to: listId, name: trimmed)
        newItemName = ""
    }
}

// MARK: - Item row

struct ItemRow: View {
    let item: ListItem
    let listId: UUID
    let onTapEdit: () -> Void
    @EnvironmentObject var listViewModel: ListViewModel
    @Environment(\.editMode) var editMode

    var body: some View {
        HStack(spacing: 12) {
            // Check / uncheck
            Button {
                listViewModel.toggleCheck(item, in: listId)
            } label: {
                Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(item.isChecked ? Color.secondary : .blue)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)

            // Name + metadata — tapping opens edit (disabled in reorder mode)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .strikethrough(item.isChecked && !item.isStaple)
                    .foregroundStyle(item.isChecked && !item.isStaple ? Color.secondary : Color.primary)

                if let meta = item.metaLine {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard editMode?.wrappedValue != .active else { return }
                onTapEdit()
            }

            // Staple indicator
            if item.isStaple {
                Image(systemName: "bookmark.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                listViewModel.toggleStaple(item, in: listId)
            } label: {
                Label(
                    item.isStaple ? "Remove Staple" : "Make Staple",
                    systemImage: item.isStaple ? "bookmark.slash" : "bookmark"
                )
            }
            Divider()
            Button(role: .destructive) {
                listViewModel.deleteItem(item, from: listId)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Item edit sheet

struct ItemEditSheet: View {
    let originalItem: ListItem?
    let listId: UUID
    let isNew: Bool
    @EnvironmentObject var listViewModel: ListViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var quantityEnabled: Bool
    @State private var quantity: Int
    @State private var weightEnabled: Bool
    @State private var weightText: String
    @State private var weightUnit: WeightUnit
    @State private var note: String

    init(item: ListItem?, listId: UUID, isNew: Bool) {
        self.originalItem = item
        self.listId = listId
        self.isNew = isNew
        _name = State(initialValue: item?.name ?? "")
        _quantityEnabled = State(initialValue: item?.quantity != nil)
        _quantity = State(initialValue: item?.quantity ?? 1)
        _weightEnabled = State(initialValue: item?.weightValue != nil)
        _weightText = State(initialValue: item?.weightValue.map { String(format: "%g", $0) } ?? "")
        _weightUnit = State(initialValue: item?.weightUnit ?? .lbs)
        _note = State(initialValue: item?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Item name", text: $name)
                }

                Section {
                    Toggle("Quantity", isOn: $quantityEnabled.animation())
                    if quantityEnabled {
                        Stepper("Qty: \(quantity)", value: $quantity, in: 1...999)
                    }
                }

                Section {
                    Toggle("Weight", isOn: $weightEnabled.animation())
                    if weightEnabled {
                        HStack {
                            TextField("Amount", text: $weightText)
                                .keyboardType(.decimalPad)
                            Picker("Unit", selection: $weightUnit) {
                                ForEach(WeightUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                        }
                    }
                }

                Section("Note") {
                    TextField("Optional description", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }
            }
            .navigationTitle(isNew ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let parsedWeight = weightEnabled ? Double(weightText) : nil
        let parsedQty = quantityEnabled ? quantity : nil
        let parsedNote = note.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : note.trimmingCharacters(in: .whitespaces)

        if isNew {
            listViewModel.addItem(
                to: listId, name: trimmedName,
                quantity: parsedQty, weightValue: parsedWeight, weightUnit: weightUnit, note: parsedNote
            )
        } else if var updated = originalItem {
            updated.name = trimmedName
            updated.quantity = parsedQty
            updated.weightValue = parsedWeight
            updated.weightUnit = weightUnit
            updated.note = parsedNote
            listViewModel.updateItem(updated, in: listId)
        }

        dismiss()
    }
}

// MARK: - Store picker sheet

struct StorePickerSheet: View {
    let stores: [GroceryStore]
    let currentStoreId: String?
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        HStack {
                            Text("No linked store")
                                .foregroundStyle(.primary)
                            Spacer()
                            if currentStoreId == nil {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                            }
                        }
                    }
                }

                if !stores.isEmpty {
                    Section("My Stores") {
                        ForEach(stores) { store in
                            Button {
                                onSelect(store.id)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.name)
                                            .foregroundStyle(.primary)
                                        Text(store.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if store.id == currentStoreId {
                                        Image(systemName: "checkmark").foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Link to Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
