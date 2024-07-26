//
//  CodeFile.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/25.
//

import Foundation

struct CodeFile: Identifiable {
    let id: URL
    var url: URL
    var content: String
    var fileType: String
    
    init(url: URL, content: String) {
        self.id = url
        self.url = url
        self.content = content
        self.fileType = url.pathExtension.lowercased()
    }
}
