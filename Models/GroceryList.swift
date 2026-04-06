//
//  GroceryList.swift
//  StorePal
//
//  Created by Carlo Latasa on 3/30/26.
//

import Foundation

enum WeightUnit: String, Codable, CaseIterable {
    case lbs
    case kg
}

struct Recipe: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var items: [ListItem]

    init(id: UUID = UUID(), name: String, items: [ListItem] = []) {
        self.id    = id
        self.name  = name
        self.items = items
    }

    /// True when every item is checked off.
    var isComplete: Bool { !items.isEmpty && items.allSatisfy(\.isChecked) }
}

struct GroceryList: Identifiable, Codable, Equatable {
     let id: UUID
     var name: String
     var items: [ListItem]
     var recipes: [Recipe]

     var boundStoreId: String?

     // MARK: Shared Lists
     var isShared: Bool = false
     /// CloudKit record name for the SharedList record (nil if not yet shared / joined)
     var cloudListId: String?
     /// true = I created this shared list; false = I joined someone else's
     var isMine: Bool = true
     /// The 6-char invite code (only set on the owner's device)
     var shareCode: String?

     init(id: UUID = UUID(), name: String, items: [ListItem] = [], recipes: [Recipe] = [],
          boundStoreId: String? = nil, isShared: Bool = false, cloudListId: String? = nil,
          isMine: Bool = true, shareCode: String? = nil) {
         self.id           = id
         self.name         = name
         self.items        = items
         self.recipes      = recipes
         self.boundStoreId = boundStoreId
         self.isShared     = isShared
         self.cloudListId  = cloudListId
         self.isMine       = isMine
         self.shareCode    = shareCode
     }

     // Custom decoder so existing persisted data (which has no "recipes" key) loads cleanly.
     init(from decoder: Decoder) throws {
         let c = try decoder.container(keyedBy: CodingKeys.self)
         id           = try c.decode(UUID.self,       forKey: .id)
         name         = try c.decode(String.self,     forKey: .name)
         items        = try c.decode([ListItem].self,  forKey: .items)
         recipes      = try c.decodeIfPresent([Recipe].self, forKey: .recipes) ?? []
         boundStoreId = try c.decodeIfPresent(String.self,  forKey: .boundStoreId)
         isShared     = try c.decodeIfPresent(Bool.self,    forKey: .isShared)     ?? false
         cloudListId  = try c.decodeIfPresent(String.self,  forKey: .cloudListId)
         isMine       = try c.decodeIfPresent(Bool.self,    forKey: .isMine)       ?? true
         shareCode    = try c.decodeIfPresent(String.self,  forKey: .shareCode)
     }

     /// Number of unchecked standalone items + unchecked recipe items.
     var activeCount: Int {
         items.filter { !$0.isChecked }.count +
         recipes.flatMap(\.items).filter { !$0.isChecked }.count
     }
 }

 struct ListItem: Identifiable, Codable, Equatable {
     let id: UUID
     var name: String
     var isChecked: Bool
     /// Staple items are never deleted by Clear Completed — they are unchecked instead.
     var isStaple: Bool
     var quantity: Int?
     var weightValue: Double?
     var weightUnit: WeightUnit
     var note: String?
     var purchasedDate: Date?

     init(id: UUID = UUID(), name: String, isChecked: Bool = false, isStaple: Bool = false,
          quantity: Int? = nil, weightValue: Double? = nil, weightUnit: WeightUnit = .lbs,
          note: String? = nil, purchasedDate: Date? = nil) {
         self.id = id
         self.name = name
         self.isChecked = isChecked
         self.isStaple = isStaple
         self.quantity = quantity
         self.weightValue = weightValue
         self.weightUnit = weightUnit
         self.note = note
         self.purchasedDate = purchasedDate
     }

     /// Secondary display line combining quantity, weight, and note when present.
     var metaLine: String? {
         var parts: [String] = []
         if let qty = quantity { parts.append("Qty: \(qty)") }
         if let w = weightValue { parts.append("\(String(format: "%g", w)) \(weightUnit.rawValue)") }
         if let n = note, !n.isEmpty { parts.append(n) }
         return parts.isEmpty ? nil : parts.joined(separator: " · ")
     }
 }
