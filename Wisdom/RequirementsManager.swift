//
//  RequirementsManager.swift
//  Wisdom
//
//  Created by Norikazu Muramoto on 2024/07/29.
//

import Foundation

class RequirementsManager {
    static let shared = RequirementsManager()
    
    private init() {}
    
    func ensureRequirementsFiles(in directory: URL) {
        let requirementsURL = directory.appendingPathComponent("REQUIREMENTS.md")
        let featureTodoURL = directory.appendingPathComponent("FEATURE_TODO.md")
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: requirementsURL.path) {
            createRequirementsFile(at: requirementsURL)
        }
        
        if !fileManager.fileExists(atPath: featureTodoURL.path) {
            createFeatureTodoFile(at: featureTodoURL)
        }
    }
    
    private func createRequirementsFile(at url: URL) {
        let content = """
        # Product Requirements Document
        
        ## Project Overview
        [Brief description of the product and its main purpose]
        
        ## Development Environment
        - Language: [e.g., Swift 5.5]
        - Framework: [e.g., SwiftUI]
        - Deployment Target: [e.g., iOS 15.0+]
        - Key Dependencies: [List only crucial dependencies]
        
        ## Core Functionality
        1. [Key function 1]
        2. [Key function 2]
        3. [Key function 3]
        
        ## Architecture
        - Pattern: [e.g., MVVM]
        - Key Components: [e.g., Views, ViewModels, Models, Services]
        """
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            print("REQUIREMENTS.md created successfully at \(url.path)")
        } catch {
            print("Error creating REQUIREMENTS.md: \(error)")
        }
    }
    
    private func createFeatureTodoFile(at url: URL) {
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
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            print("FEATURE_TODO.md created successfully at \(url.path)")
        } catch {
            print("Error creating FEATURE_TODO.md: \(error)")
        }
    }
}
