//
//  Item.swift
//  Guitar Tuner
//
//  Created by William Tower on 2026-06-08.
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
