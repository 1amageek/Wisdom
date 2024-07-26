//
//  ChatMessage.swift
//
//
//  Created by Norikazu Muramoto on 2024/07/24.
//

import Foundation


struct ChatMessage: Identifiable, Codable, Equatable {
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
    
    enum Role: String, Codable {
        case model
        case user
        case tool
    }
    
    struct Content: Codable {
        var text: String
    }
    
    var isUser: Bool { role == .user }
    
    var id: String
    var content: [Content]
    var role: Role
    var timestamp: Date
}
