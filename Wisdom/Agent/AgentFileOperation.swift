//
//  AgentFileOperation.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/28.
//

import Foundation

public enum AgentFileOperationType {
    case create
    case update
    case delete
}

public struct AgentFileOperation {
    public let type: AgentFileOperationType
    public let path: String
    public let content: String?
    
    public init(type: AgentFileOperationType, path: String, content: String? = nil) {
        self.type = type
        self.path = path
        self.content = content
    }
}
