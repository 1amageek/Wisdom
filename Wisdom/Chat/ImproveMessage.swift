//
//  ImproveMessage.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/26.
//

import Foundation


struct ImproveMessage: Identifiable, Codable {
    var id: String
    var operations: [AgentAction]
    var text: String
    var timestamp: Date
}
