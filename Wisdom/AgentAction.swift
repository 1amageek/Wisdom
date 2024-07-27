//
//  AgentAction.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/27.
//

import Foundation

enum ActionType: String, Codable {
    case create
    case update
    case delete
}

struct AgentAction: Identifiable, Codable {
    var id: String
    var url: URL
    var actionType: ActionType
    var content: String?
}
