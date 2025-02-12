//
//  Item.swift
//  LanguageTool
//
//  Created by 华子 on 2025/2/12.
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
