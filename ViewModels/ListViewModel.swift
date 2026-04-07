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

    func addItem(to listId: UUID, name: String, quantity: Int? = nil,
                 weightValue: Double? = nil, weightUnit: WeightUnit = .lbs, note: String? = nil) {
        guard let li = lists.firstIndex(where: { $0.id == listId }) else { return }
        let item = ListItem(name: name, quantity: quantity,
                            weightValue: weightValue, weightUnit: weightUnit, note: note)
        lists[li].items.append(item)
        let list = lists[li]
        let index = list.items.count - 1
        pushItemChange(item, sortOrder: index, in: list)
    }

    func updateItem(_ item: ListItem, in listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }),
              let ii = lists[li].items.firstIndex(where: { $0.id == item.id }) else { return }
        lists[li].items[ii] = item
        pushItemChange(item, sortOrder: ii, in: lists[li])
    }

    func bindList(_ listId: UUID, to storeId: String?) {
        guard let i = lists.firstIndex(where: { $0.id == listId }) else { return }
        lists[i].boundStoreId = storeId
    }

    func moveItem(in listId: UUID, from source: IndexSet, to destination: Int) {
        guard let li = lists.firstIndex(where: { $0.id == listId }) else { return }
        lists[li].items.move(fromOffsets: source, toOffset: destination)
        pushAllItems(for: lists[li])
    }

    func toggleCheck(_ item: ListItem, in listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }),
              let ii = lists[li].items.firstIndex(where: { $0.id == item.id }) else { return }
        lists[li].items[ii].isChecked.toggle()
        if lists[li].items[ii].isChecked {
            lists[li].items[ii].purchasedDate = Date()
        }
        pushItemChange(lists[li].items[ii], sortOrder: ii, in: lists[li])
    }

    func toggleStaple(_ item: ListItem, in listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }),
              let ii = lists[li].items.firstIndex(where: { $0.id == item.id }) else { return }
        lists[li].items[ii].isStaple.toggle()
        pushItemChange(lists[li].items[ii], sortOrder: ii, in: lists[li])
    }

    func deleteItem(_ item: ListItem, from listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }) else { return }
        pushItemDelete(itemId: item.id, in: lists[li])
        lists[li].items.removeAll { $0.id == item.id }
    }

    /// Non-staple checked items are deleted.
    /// Staple checked items are unchecked (reset) so they remain on the list.
    /// Recipe items are always unchecked (never deleted) since recipes are reusable.
    func clearCompleted(from listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }) else { return }
        // Delete non-staple checked items from cloud
        for item in lists[li].items where item.isChecked && !item.isStaple {
            pushItemDelete(itemId: item.id, in: lists[li])
        }
        for ii in lists[li].items.indices {
            if lists[li].items[ii].isStaple && lists[li].items[ii].isChecked {
                lists[li].items[ii].isChecked = false
                lists[li].items[ii].purchasedDate = nil
            }
        }
        lists[li].items.removeAll { $0.isChecked && !$0.isStaple }
        // Reset all checked recipe items so the recipe is ready for next time.
        for ri in lists[li].recipes.indices {
            for ii in lists[li].recipes[ri].items.indices where lists[li].recipes[ri].items[ii].isChecked {
                lists[li].recipes[ri].items[ii].isChecked = false
                lists[li].recipes[ri].items[ii].purchasedDate = nil
            }
        }
        pushAllItems(for: lists[li])
    }

    // MARK: - Recipe management

    func addRecipe(to listId: UUID, name: String, items: [ListItem]) {
        guard let li = lists.firstIndex(where: { $0.id == listId }) else { return }
        let recipe = Recipe(name: name, items: items)
        lists[li].recipes.append(recipe)
        pushRecipeChange(recipe, sortOrder: lists[li].recipes.count - 1, in: lists[li])
    }

    func updateRecipe(_ recipe: Recipe, in listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }),
              let ri = lists[li].recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        lists[li].recipes[ri] = recipe
        pushRecipeChange(recipe, sortOrder: ri, in: lists[li])
    }

    func deleteRecipe(_ recipe: Recipe, from listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }) else { return }
        pushRecipeDelete(recipeId: recipe.id, in: lists[li])
        lists[li].recipes.removeAll { $0.id == recipe.id }
    }

    /// Tapping the recipe-level checkbox checks all items if any are unchecked, or unchecks all if all are checked.
    func toggleCheckRecipe(_ recipe: Recipe, in listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }),
              let ri = lists[li].recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        let allChecked = lists[li].recipes[ri].items.allSatisfy(\.isChecked)
        let now = Date()
        for ii in lists[li].recipes[ri].items.indices {
            lists[li].recipes[ri].items[ii].isChecked = !allChecked
            if !allChecked {
                lists[li].recipes[ri].items[ii].purchasedDate = now
            }
        }
    }

    func toggleCheckRecipeItem(_ item: ListItem, recipeId: UUID, in listId: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listId }),
              let ri = lists[li].recipes.firstIndex(where: { $0.id == recipeId }),
              let ii = lists[li].recipes[ri].items.firstIndex(where: { $0.id == item.id }) else { return }
        lists[li].recipes[ri].items[ii].isChecked.toggle()
        if lists[li].recipes[ri].items[ii].isChecked {
            lists[li].recipes[ri].items[ii].purchasedDate = Date()
        }
    }

    // MARK: - Sharing

    func shareList(_ list: GroceryList) async throws -> String {
        await CloudKitService.shared.checkAvailability()
        guard CloudKitService.shared.isAvailable else {
            throw CloudKitError.notAuthenticated(CloudKitService.shared.errorMessage)
        }

        let payloads = list.items.enumerated().map { index, item in item.payload(sortOrder: index) }
        let code = try await CloudKitService.shared.shareList(
            name: list.name, listId: list.id, items: payloads, recipes: list.recipes)

        guard let i = lists.firstIndex(where: { $0.id == list.id }) else { return code }
        let cloudListId = "list-\(list.id.uuidString)"
        lists[i].isShared = true
        lists[i].cloudListId = cloudListId
        lists[i].isMine = true
        lists[i].shareCode = code

        _ = try? await CloudKitService.shared.subscribeToListChanges(cloudListId: cloudListId)
        return code
    }

    func joinList(shareCode: String) async throws {
        await CloudKitService.shared.checkAvailability()
        guard CloudKitService.shared.isAvailable else {
            throw CloudKitError.notAuthenticated(CloudKitService.shared.errorMessage)
        }

        let (cloudListId, listName) = try await CloudKitService.shared.joinList(shareCode: shareCode)

        // Guard against joining the same list twice
        guard !lists.contains(where: { $0.cloudListId == cloudListId }) else {
            throw CloudKitError.alreadyJoined
        }

        let payloads = try await CloudKitService.shared.fetchItems(cloudListId: cloudListId)
        let recipes  = (try? await CloudKitService.shared.fetchRecipes(cloudListId: cloudListId)) ?? []
        var newList = GroceryList(name: listName)
        newList.isShared = true
        newList.cloudListId = cloudListId
        newList.isMine = false
        newList.items   = payloads.map { $0.asListItem }
        newList.recipes = recipes
        lists.append(newList)

        _ = try? await CloudKitService.shared.subscribeToListChanges(cloudListId: cloudListId)
    }

    /// Pull latest items and recipes from CloudKit for every shared list.
    func syncSharedLists() async {
        guard lists.contains(where: { $0.isShared }) else { return }
        for list in lists where list.isShared {
            guard let cloudListId = list.cloudListId else { continue }
            guard let i = lists.firstIndex(where: { $0.id == list.id }) else { continue }
            if let payloads = try? await CloudKitService.shared.fetchItems(cloudListId: cloudListId) {
                lists[i].items = payloads.map { $0.asListItem }
            }
            if let recipes = try? await CloudKitService.shared.fetchRecipes(cloudListId: cloudListId) {
                lists[i].recipes = recipes
            }
        }
    }

    /// Owner: deletes CloudKit records and converts list back to local. Participant: removes local copy entirely.
    func leaveSharedList(_ list: GroceryList) async {
        guard let cloudListId = list.cloudListId else { return }
        _ = try? await CloudKitService.shared.leaveList(cloudListId: cloudListId, isOwner: list.isMine)
        await CloudKitService.shared.unsubscribe(cloudListId: cloudListId)

        if list.isMine {
            // Owner: keep the list locally, just strip the sharing metadata
            guard let i = lists.firstIndex(where: { $0.id == list.id }) else { return }
            lists[i].isShared    = false
            lists[i].cloudListId = nil
            lists[i].shareCode   = nil
            lists[i].isMine      = true
        } else {
            // Participant: remove the list entirely (it belongs to someone else)
            deleteList(list)
        }
    }

    // MARK: - Cloud push helpers (fire-and-forget)

    private func pushItemChange(_ item: ListItem, sortOrder: Int, in list: GroceryList) {
        guard list.isShared, let cloudListId = list.cloudListId else { return }
        Task { try? await CloudKitService.shared.saveItem(item.payload(sortOrder: sortOrder),
                                                          cloudListId: cloudListId,
                                                          sortOrder: sortOrder) }
    }

    private func pushItemDelete(itemId: UUID, in list: GroceryList) {
        guard list.isShared, let cloudListId = list.cloudListId else { return }
        Task { try? await CloudKitService.shared.deleteItem(cloudListId: cloudListId,
                                                            itemId: itemId.uuidString) }
    }

    private func pushAllItems(for list: GroceryList) {
        guard list.isShared, let cloudListId = list.cloudListId else { return }
        let snapshot = list.items
        Task {
            for (index, item) in snapshot.enumerated() {
                try? await CloudKitService.shared.saveItem(item.payload(sortOrder: index),
                                                           cloudListId: cloudListId,
                                                           sortOrder: index)
            }
        }
    }

    private func pushRecipeChange(_ recipe: Recipe, sortOrder: Int, in list: GroceryList) {
        guard list.isShared, let cloudListId = list.cloudListId else { return }
        Task { try? await CloudKitService.shared.saveRecipe(recipe, cloudListId: cloudListId, sortOrder: sortOrder) }
    }

    private func pushRecipeDelete(recipeId: UUID, in list: GroceryList) {
        guard list.isShared, let cloudListId = list.cloudListId else { return }
        Task { try? await CloudKitService.shared.deleteRecipe(recipeId: recipeId.uuidString, cloudListId: cloudListId) }
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
