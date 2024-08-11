//
//  FileItemSection.swift
//
//
//  Created by Norikazu Muramoto on 2024/08/12.
//

import Foundation

public struct FileItemSection: Identifiable {
    
    public var id: String { item.id }
    
    public var name: String
    
    public var item: FileItem
    
    public init(name: String, item: FileItem) {
        self.name = name
        self.item = item
    }
}
