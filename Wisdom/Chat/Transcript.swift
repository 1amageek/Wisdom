//
//  Transcript.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/26.
//

import Foundation


struct Transcript: Identifiable, Codable {
    var id: String
    var operations: [AgentFileOperation]
    var text: String
    var timestamp: Date
}
