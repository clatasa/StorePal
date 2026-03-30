//
//  GroceryList.swift
//  StorePal
//
//  Created by Carlo Latasa on 3/30/26.
//

import Foundation
struct GroceryList: Identifiable, Codable, Equatable {
     let id: UUID
     var name: String
     var items: [ListItem]

     init(id: UUID = UUID(), name: String, items: [ListItem] = []) {
         self.id = id
         self.name = name
         self.items = items
     }

     /// Number of unchecked items
     var activeCount: Int { items.filter { !$0.isChecked }.count }

     static func == (lhs: GroceryList, rhs: GroceryList) -> Bool { lhs.id == rhs.id }
 }

 struct ListItem: Identifiable, Codable, Equatable {
     let id: UUID
     var name: String
     var isChecked: Bool
     /// Staple items are never deleted by Clear Completed — they are unchecked instead.
     var isStaple: Bool

     init(id: UUID = UUID(), name: String, isChecked: Bool = false, isStaple: Bool = false) {
         self.id = id
         self.name = name
         self.isChecked = isChecked
         self.isStaple = isStaple
     }

     static func == (lhs: ListItem, rhs: ListItem) -> Bool { lhs.id == rhs.id }
 }
