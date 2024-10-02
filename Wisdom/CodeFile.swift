//
//  CodeFile.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/25.
//

import Foundation

struct CodeFile: Identifiable {
    let id: String
    var url: URL
    var content: String
    var fileType: String
    
    init(url: URL, content: String) {
        self.id = url.absoluteString
        self.url = url
        self.content = content
        self.fileType = url.pathExtension.lowercased()
    }
    
    static func from(_ fileItem: FileItem) -> CodeFile {
        let content = try! String(contentsOf: fileItem.url, encoding: .utf8)
        return CodeFile(
            url: fileItem.url,
            content: content
        )
    }
}
