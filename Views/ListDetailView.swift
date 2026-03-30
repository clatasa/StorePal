internal import SwiftUI

struct ListDetailView: View {
    let listId: UUID
    @EnvironmentObject var listViewModel: ListViewModel
    @Environment(\.dismiss) var dismiss

    @State private var newItemName = ""
    @State private var showRenameAlert = false
    @State private var pendingRename = ""
    @FocusState private var isAddFieldFocused: Bool

    private var list: GroceryList? {
        listViewModel.lists.first { $0.id == listId }
    }

    // Unchecked items first, checked items last — preserves insertion order within each group
    private var sortedItems: [ListItem] {
        guard let list else { return [] }
        return list.items.filter { !$0.isChecked } + list.items.filter { $0.isChecked }
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
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
        }
    }

    // MARK: - List content

    @ViewBuilder
    private func listContent(_ list: GroceryList) -> some View {
        List {
            if sortedItems.isEmpty {
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
                ForEach(sortedItems) { item in
                    ItemRow(item: item, listId: listId)
                        .environmentObject(listViewModel)
                }
                .onDelete { offsets in
                    offsets.map { sortedItems[$0] }.forEach {
                        listViewModel.deleteItem($0, from: listId)
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
    @EnvironmentObject var listViewModel: ListViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Check / uncheck
            Button {
                listViewModel.toggleCheck(item, in: listId)
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? Color.secondary : .blue)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)

            // Name — strike through non-staple checked items only
            Text(item.name)
                .strikethrough(item.isChecked && !item.isStaple)
                .foregroundStyle(
                    item.isChecked && !item.isStaple ? Color.secondary : Color.primary
                )

            Spacer()

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
