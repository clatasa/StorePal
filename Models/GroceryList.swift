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

struct GroceryList: Identifiable, Codable, Equatable {
     let id: UUID
     var name: String
     var items: [ListItem]

     var boundStoreId: String?

     init(id: UUID = UUID(), name: String, items: [ListItem] = [], boundStoreId: String? = nil) {
         self.id = id
         self.name = name
         self.items = items
         self.boundStoreId = boundStoreId
     }

     /// Number of unchecked items
     var activeCount: Int { items.filter { !$0.isChecked }.count }
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

     init(id: UUID = UUID(), name: String, isChecked: Bool = false, isStaple: Bool = false,
          quantity: Int? = nil, weightValue: Double? = nil, weightUnit: WeightUnit = .lbs, note: String? = nil) {
         self.id = id
         self.name = name
         self.isChecked = isChecked
         self.isStaple = isStaple
         self.quantity = quantity
         self.weightValue = weightValue
         self.weightUnit = weightUnit
         self.note = note
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
