//
//  Item.swift
//  StorePal
//
//  Created by Carlo Latasa on 3/27/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
