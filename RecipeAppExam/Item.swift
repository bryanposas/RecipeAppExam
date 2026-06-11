//
//  Item.swift
//  RecipeAppExam
//
//  Created by Macintosh HD on 6/11/26.
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
