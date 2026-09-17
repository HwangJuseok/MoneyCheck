//
//  Item.swift
//  MoneyCheck
//
//  Created by 주석 on 9/17/26.
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
