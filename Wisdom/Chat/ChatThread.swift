//
//  ChatThread.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/26.
//

import Foundation


struct ChatThread: Identifiable, Codable {
    let id: String
    var name: String
    var createdAt: Date
    var updatedAt: Date
}
