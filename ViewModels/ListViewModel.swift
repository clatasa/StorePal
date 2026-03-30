import Foundation
import MapKit
import Combine
internal import SwiftUI

@MainActor
class ListViewModel: ObservableObject {

    @Published var lists: [GroceryList] = [] {
        didSet { persist() }
    }

    init() { load() }

    // MARK: - List management

    func addList(name: String) {
        lists.append(GroceryList(name: name))
    }

    func deleteList(_ list: GroceryList) {
        lists.removeAll { $0.id == list.id }
    }

    func renameList(_ list: GroceryList, to name: String) {
        guard let i = lists.firstIndex(where: { $0.id == list.id }) else { return }
        lists[i].name = name
    }

    // MARK: - Item management

    func addItem(to listId: UUID, name: String) {
        guard let i = lists.firstIndex(where: { $0.id == listId }) else { return }
        lists[i].items.append(ListItem(name: name))
    }

    func toggleCheck(_ item: ListItem, in listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }),
              let ii = lists[li].items.firstIndex(where: { $0.id == item.id }) else { return }
        lists[li].items[ii].isChecked.toggle()
    }

    func toggleStaple(_ item: ListItem, in listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }),
              let ii = lists[li].items.firstIndex(where: { $0.id == item.id }) else { return }
        lists[li].items[ii].isStaple.toggle()
    }

    func deleteItem(_ item: ListItem, from listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }) else { return }
        lists[li].items.removeAll { $0.id == item.id }
    }

    /// Non-staple checked items are deleted.
    /// Staple checked items are unchecked (reset) so they remain on the list.
    func clearCompleted(from listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }) else { return }
        for ii in lists[li].items.indices {
            if lists[li].items[ii].isStaple && lists[li].items[ii].isChecked {
                lists[li].items[ii].isChecked = false
            }
        }
        lists[li].items.removeAll { $0.isChecked && !$0.isStaple }
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(data, forKey: "groceryLists")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "groceryLists"),
           let loaded = try? JSONDecoder().decode([GroceryList].self, from: data) {
            lists = loaded
        }
    }
}
