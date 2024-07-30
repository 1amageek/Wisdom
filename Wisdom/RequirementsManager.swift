//
//  RequirementsManager.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/29.
//

import Foundation

import Foundation

class RequirementsManager {
    
    static let shared = RequirementsManager()
    
    private let fileManager = FileManager.default
    private var rootURL: URL?
    private var wisdomURL: URL? {
        self.rootURL?.appendingPathComponent(".wisdom")
    }
    
    private init() {}
    
    func setRootURL(_ url: URL) {
        self.rootURL = url
    }
    
    func createFile(name: String) throws {
        guard let wisdomURL = wisdomURL else { throw RequirementsError.wisdomDirectoryNotSet }
        
        let fileURL = wisdomURL.appendingPathComponent(name).appendingPathExtension("md")
        let initialContent = "# \(name)\n\nEnter your content here."
        
        try initialContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    func readFile(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
    
    func updateFile(at url: URL, content: String) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    func context() -> String {
        guard let rootURL = rootURL else { return "" }
        guard let wisdomURL = wisdomURL else { return "" }
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: wisdomURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])            
            return try fileURLs
                .filter { $0.pathExtension.lowercased() == "md" }
                .map { url -> String in
                    let relativePath = url.relativePath(from: rootURL)
                    let content = try String(contentsOf: url, encoding: .utf8)
                    return """
                    path: \(relativePath)
                    ```markdown:\(url.lastPathComponent)
                    \(content)
                    ```
                    ---
                    """
                }
                .joined(separator: "\n\n")
        } catch {
            return ""
        }
    }

    enum RequirementsError: Error {
        case wisdomDirectoryNotSet
    }
}

// MARK: -

extension RequirementsManager {
    
    static func ensureWisdomDirectory(at url: URL) throws -> URL {
        let fileManager = FileManager.default
        let wisdomURL = url.appendingPathComponent(".wisdom")
        
        if !fileManager.fileExists(atPath: wisdomURL.path) {
            try fileManager.createDirectory(at: wisdomURL, withIntermediateDirectories: true, attributes: nil)
        }
        
//        let requirementsURL = wisdomURL.appendingPathComponent("REQUIREMENTS.md")
//        if !fileManager.fileExists(atPath: requirementsURL.path) {
//            try createRequirementsFile(at: requirementsURL)
//        }
//        let featureTodoURL = wisdomURL.appendingPathComponent("FEATURE_TODO.md")
//        if !fileManager.fileExists(atPath: featureTodoURL.path) {
//            try createFeatureTodoFile(at: featureTodoURL)
//        }
        return wisdomURL
    }
    
    static private func createRequirementsFile(at url: URL) throws {
        let content = """
        # Product Requirements Document

        ## Project Overview
        [Brief description of the product and its main purpose]

        ## Development Environment
        - Language: [e.g., Swift 5.10]
        - Framework: [e.g., SwiftUI]
        - Deployment Target: [e.g., iOS 17.0+]
        - Key Dependencies: [List only crucial dependencies]

        ## Core Functionality
        1. [Key function 1]
        2. [Key function 2]
        3. [Key function 3]

        ## Architecture
        - Pattern: [e.g., MVVM]
        - Key Components: [e.g., Views, ViewModels, Models, Services]
        """
        
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    static private func createFeatureTodoFile(at url: URL) throws {
        let content = """
        # TODO Feature

        - [ ] Create todo items
        - [ ] Delete todo items
        - [ ] Mark todos as complete/incomplete
        - [ ] Filter todos (all, active, completed)
        - [ ] Reorder todos via drag and drop
        - [ ] Add due dates to todos
        - [ ] Create subtasks for complex todos
        - [ ] Search within todos
        - [ ] Group todos by categories/projects
        - [ ] Set reminders for todos
        - [ ] Sync across devices

        Note: Checked items [x] are implemented, unchecked [ ] are not yet implemented.
        """
        
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
}
