//
//  StorePalTests.swift
//  StorePalTests
//

import XCTest
import CoreLocation
@testable import StorePal

// MARK: - Helpers

private func makeStore(id: String = "store-1", name: String = "Test Mart") -> GroceryStore {
    GroceryStore(id: id, name: name, address: "123 Main St", latitude: 37.33, longitude: -122.03)
}

private func makeList(boundTo storeId: String? = nil, items: [ListItem] = [], recipes: [Recipe] = []) -> GroceryList {
    GroceryList(name: "My List", items: items, recipes: recipes, boundStoreId: storeId)
}

private func makeItem(_ name: String, checked: Bool = false) -> ListItem {
    ListItem(name: name, isChecked: checked)
}

// MARK: - activeCount

final class ActiveCountTests: XCTestCase {

    func testNoItems() {
        XCTAssertEqual(makeList().activeCount, 0)
    }

    func testAllUnchecked() {
        let l = makeList(items: [makeItem("Milk"), makeItem("Eggs")])
        XCTAssertEqual(l.activeCount, 2)
    }

    func testMixedChecked() {
        let l = makeList(items: [makeItem("Milk"), makeItem("Eggs", checked: true), makeItem("Bread")])
        XCTAssertEqual(l.activeCount, 2)
    }

    func testAllChecked() {
        let l = makeList(items: [makeItem("Milk", checked: true), makeItem("Eggs", checked: true)])
        XCTAssertEqual(l.activeCount, 0)
    }

    func testRecipeItemsCountedWhenUnchecked() {
        let recipeItems = [makeItem("Pasta"), makeItem("Sauce", checked: true)]
        let recipe = Recipe(name: "Pasta Night", items: recipeItems)
        let l = makeList(recipes: [recipe])
        XCTAssertEqual(l.activeCount, 1)
    }

    func testStandaloneAndRecipeItemsCombined() {
        let recipeItems = [makeItem("Pasta"), makeItem("Sauce")]
        let recipe = Recipe(name: "Pasta Night", items: recipeItems)
        // 1 unchecked standalone + 2 unchecked recipe = 3
        let l = makeList(items: [makeItem("Milk"), makeItem("Eggs", checked: true)], recipes: [recipe])
        XCTAssertEqual(l.activeCount, 3)
    }
}

// MARK: - Geofence alert decision logic

final class GeofenceAlertPayloadTests: XCTestCase {

    private let s = makeStore()

    // MARK: .always

    func testAlwaysFiresRegardlessOfLists() {
        let payload = LocationService.alertPayload(storeId: s.id, stores: [s], lists: [], behavior: .always)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.store.id, s.id)
        XCTAssertNil(payload?.listName)
        XCTAssertNil(payload?.itemCount)
        XCTAssertNil(payload?.listId)
    }

    func testAlwaysFiresEvenWithUnboundList() {
        let l = makeList(boundTo: nil, items: [makeItem("Milk")])
        let payload = LocationService.alertPayload(storeId: s.id, stores: [s], lists: [l], behavior: .always)
        XCTAssertNotNil(payload)
    }

    func testAlwaysSilentWhenStoreNotFound() {
        let payload = LocationService.alertPayload(storeId: "unknown-id", stores: [s], lists: [], behavior: .always)
        XCTAssertNil(payload)
    }

    // MARK: .linkedList

    func testLinkedListFiresWhenBound() {
        let l = makeList(boundTo: s.id)
        let payload = LocationService.alertPayload(storeId: s.id, stores: [s], lists: [l], behavior: .linkedList)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.listName, l.name)
        XCTAssertNil(payload?.itemCount)
        XCTAssertEqual(payload?.listId, l.id)
    }

    func testLinkedListSilentWhenNoListBound() {
        let l = makeList(boundTo: nil)
        let payload = LocationService.alertPayload(storeId: s.id, stores: [s], lists: [l], behavior: .linkedList)
        XCTAssertNil(payload)
    }

    func testLinkedListSilentWhenBoundToDifferentStore() {
        let l = makeList(boundTo: "other-store-id")
        let payload = LocationService.alertPayload(storeId: s.id, stores: [s], lists: [l], behavior: .linkedList)
        XCTAssertNil(payload)
    }

    func testLinkedListFiresEvenWithAllChecked() {
        // .linkedList doesn't care about item state — just whether a list is bound
        let l = makeList(boundTo: s.id, items: [makeItem("Milk", checked: true)])
        let payload = LocationService.alertPayload(storeId: s.id, stores: [s], lists: [l], behavior: .linkedList)
        XCTAssertNotNil(payload)
    }

    // MARK: .itemsNeeded

    func testItemsNeededFiresWhenUncheckedItemsExist() {
        let l = makeList(boundTo: s.id, items: [makeItem("Milk"), makeItem("Eggs")])
        let payload = LocationService.alertPayload(storeId: s.id, stores: [s], lists: [l], behavior: .itemsNeeded)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.itemCount, 2)
        XCTAssertEqual(payload?.listName, l.name)
        XCTAssertEqual(payload?.listId, l.id)
    }

    func testItemsNeededSilentWhenAllChecked() {
        let l = makeList(boundTo: s.id, items: [makeItem("Milk", checked: true), makeItem("Eggs", checked: true)])
        let payload = LocationService.alertPayload(storeId: s.id, stores: [s], lists: [l], behavior: .itemsNeeded)
        XCTAssertNil(payload)
    }

    func testItemsNeededSilentWhenUnbound() {
        let l = makeList(boundTo: nil, items: [makeItem("Milk")])
        let payload = LocationService.alertPayload(storeId: s.id, stores: [s], lists: [l], behavior: .itemsNeeded)
        XCTAssertNil(payload)
    }

    func testItemsNeededSilentWhenListEmpty() {
        let l = makeList(boundTo: s.id, items: [])
        let payload = LocationService.alertPayload(storeId: s.id, stores: [s], lists: [l], behavior: .itemsNeeded)
        XCTAssertNil(payload)
    }

    func testItemsNeededCountsUncheckedOnly() {
        let l = makeList(boundTo: s.id, items: [makeItem("Milk"), makeItem("Eggs", checked: true), makeItem("Bread")])
        let payload = LocationService.alertPayload(storeId: s.id, stores: [s], lists: [l], behavior: .itemsNeeded)
        XCTAssertEqual(payload?.itemCount, 2)
    }

    func testItemsNeededPicksFirstMatchingList() {
        // Two lists bound to the same store — first one with active items wins
        let l1 = makeList(boundTo: s.id, items: [makeItem("Milk")])
        let l2 = makeList(boundTo: s.id, items: [makeItem("Eggs")])
        let payload = LocationService.alertPayload(storeId: s.id, stores: [s], lists: [l1, l2], behavior: .itemsNeeded)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.itemCount, 1)
    }

    // MARK: UserDefaults round-trip

    func testUserDefaultsRoundTripPreservesBindingAndItems() throws {
        let s = makeStore()
        let items = [makeItem("Apples"), makeItem("Milk", checked: true)]
        let l = makeList(boundTo: s.id, items: items)

        // Write exactly as the app does
        UserDefaults.standard.set(try JSONEncoder().encode([s]), forKey: "favorites")
        UserDefaults.standard.set(try JSONEncoder().encode([l]), forKey: "groceryLists")
        defer {
            UserDefaults.standard.removeObject(forKey: "favorites")
            UserDefaults.standard.removeObject(forKey: "groceryLists")
        }

        // Read exactly as didEnterRegion does
        let readStores = try JSONDecoder().decode([GroceryStore].self,
                             from: XCTUnwrap(UserDefaults.standard.data(forKey: "favorites")))
        let readLists  = try JSONDecoder().decode([GroceryList].self,
                             from: XCTUnwrap(UserDefaults.standard.data(forKey: "groceryLists")))

        XCTAssertEqual(readStores.first?.id, s.id)
        XCTAssertEqual(readLists.first?.boundStoreId, s.id)
        XCTAssertEqual(readLists.first?.activeCount, 1) // only Apples is unchecked

        // Verify the full decision fires correctly end-to-end
        let payload = LocationService.alertPayload(
            storeId: s.id, stores: readStores, lists: readLists, behavior: .itemsNeeded
        )
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.itemCount, 1)
    }
}
